# Pipeline CI/CD com Security Gates

Pipeline DevSecOps com verificações de segurança automáticas antes do deploy. O objetivo é demonstrar o conceito de **shift-left security** — trazer as verificações de segurança para o início do ciclo de desenvolvimento, antes que o código chegue em produção.

## O que é Shift-Left Security?

Tradicionalmente, segurança era verificada no final do ciclo de desenvolvimento. Shift-left significa mover essas verificações para a esquerda no pipeline — mais cedo, mais rápido, mais barato de corrigir. Cada gate neste pipeline representa uma camada de defesa:

- Secrets no código → detectado antes do merge
- Misconfiguration de infraestrutura → detectado antes do deploy
- Vulnerabilidades na imagem → detectado antes de subir para produção

## Ferramentas utilizadas

### Gitleaks
Ferramenta open source de detecção de secrets e credenciais expostas no código-fonte. Analisa o histórico de commits em busca de padrões como chaves de API, tokens, senhas e certificados. Evita que credenciais acidentalmente commitadas vazem para o repositório público.

- **O que detecta:** AWS keys, tokens GitHub/GitLab, senhas hardcoded, chaves privadas, tokens JWT, e centenas de outros padrões
- **Como funciona:** usa expressões regulares e entropia para identificar strings suspeitas
- **Site:** [gitleaks.io](https://gitleaks.io)

### Checkov
Ferramenta de análise estática de Infrastructure as Code (IaC). Lê arquivos Terraform, CloudFormation, Kubernetes e outros formatos sem executar nada — analisa o código e compara contra um banco de mais de 1000 políticas de segurança.

- **O que detecta:** buckets S3 públicos, security groups abertos, encryption desabilitada, MFA desativado, logging ausente, e dezenas de outras misconfigurations
- **Como funciona:** analisa o grafo de recursos do Terraform e verifica cada um contra as políticas do CIS Benchmark e outras frameworks
- **Site:** [checkov.io](https://www.checkov.io)

### Trivy
Scanner de vulnerabilidades open source da Aqua Security. Analisa imagens Docker em busca de CVEs (Common Vulnerabilities and Exposures) conhecidos nos pacotes do sistema operacional e nas dependências da aplicação.

- **O que detecta:** CVEs em pacotes OS (Debian, Alpine, etc.), dependências Python/Node/Go/Java, misconfigurations em Dockerfiles e IaC
- **Como funciona:** compara os pacotes instalados na imagem contra bases de dados de vulnerabilidades (NVD, GitHub Advisory, etc.)
- **Site:** [aquasecurity.github.io/trivy](https://aquasecurity.github.io/trivy)

---

## Security Gates

| Gate | Ferramenta | O que detecta |
|------|-----------|---------------|
| Secret Scan | Gitleaks | Senhas e tokens no código |
| IaC Scan | Checkov | Misconfigurations no Terraform |
| Container Scan | Trivy | CVEs críticos/altos com fix disponível |
| Deploy | — | Só executa se todos passarem |

## Como funciona

1. Push para qualquer branch dispara o pipeline
2. Os 3 jobs de segurança rodam em paralelo
3. Se qualquer gate falhar, o deploy é bloqueado
4. Deploy só acontece em push para `main` com todos os gates verdes

```
Push → [ Gitleaks ] ─┐
                      ├─ todos OK? → Deploy ✅
Push → [ Checkov  ] ─┤
                      │
Push → [ Trivy    ] ─┘
           ↓
      qualquer falha → Deploy bloqueado ❌
```

## Evidências

O pipeline foi testado com misconfigurations intencionais:

**Commit 1 — pipeline falhando (intencional):**
- Bucket S3 sem encryption, versioning, logging, replicação → Checkov detecta 7 falhas e bloqueia
- Imagem Docker `python:3.9` com CVEs conhecidos → Trivy detecta e bloqueia
- Deploy não executa

**Commit 2 — pipeline passando após correções:**
- Bucket S3 com todas as configurações de segurança aplicadas
- Imagem Docker atualizada para `python:3.13-slim` sem CVEs com fix disponível
- Todos os gates verdes → Deploy liberado

---

## Infraestrutura (Terraform)

O código Terraform provisiona um bucket S3 seguindo as melhores práticas de segurança:

| Configuração | Recurso Terraform | Por quê |
|---|---|---|
| Encryption com KMS | `aws_s3_bucket_server_side_encryption_configuration` | Dados em repouso criptografados com chave gerenciada |
| Versioning | `aws_s3_bucket_versioning` | Recuperação de objetos deletados ou sobrescritos |
| Block Public Access | `aws_s3_bucket_public_access_block` | Evita exposição acidental de dados |
| Access Logging | `aws_s3_bucket_logging` | Auditoria de quem acessou o quê e quando |
| Lifecycle Policy | `aws_s3_bucket_lifecycle_configuration` | Gerenciamento de custos e retenção de dados |
| Cross-Region Replication | `aws_s3_bucket_replication_configuration` | Resiliência e disaster recovery |
| Event Notifications | `aws_s3_bucket_notification` | Integração com EventBridge para automações |
| KMS Key Policy | `aws_kms_key` | Controle explícito de quem pode usar a chave |

---

## Decisões arquiteturais

### Checkov — skips documentados

Dois recursos possuem `checkov:skip` para a regra `CKV_AWS_144` (cross-region replication):

- **`aws_s3_bucket.log_bucket`** — bucket de access logging não requer replicação cross-region. Logs são dados operacionais, não dados de negócio. Replicá-los criaria dependência circular: o bucket replica também precisaria de um bucket de log, que precisaria de replicação, e assim por diante.
- **`aws_s3_bucket.replica_log_bucket`** — mesma razão. É o bucket de log dedicado à região de replica (`us-west-2`).

Todos os outros recursos estão em conformidade total com as regras do Checkov.

### Trivy — CVEs sem fix disponível

O Trivy está configurado com `ignore-unfixed: true`. Isso significa que CVEs com status `affected` ou `fix_deferred` (sem patch disponível pelo mantenedor) não bloqueiam o pipeline.

Bloquear o deploy por vulnerabilidades sem correção disponível não agrega segurança — apenas impede entregas. A abordagem correta é monitorar esses CVEs e agir assim que um fix for publicado.

### Gitleaks — primeiro commit

A action `gitleaks/gitleaks-action@v2` retorna exit code 1 no primeiro commit do repositório por não encontrar um commit pai para comparar. Nenhum secret foi detectado (`no leaks found`). Esse é um bug conhecido da action e não representa risco real.

---

## Stack

- **IaC:** Terraform + AWS Provider ~5.0
- **CI/CD:** GitHub Actions
- **Secret Scan:** Gitleaks 8.x
- **IaC Scan:** Checkov (bridgecrewio/checkov-action)
- **Container Scan:** Trivy (aquasecurity/trivy-action)
- **Cloud:** AWS (S3, KMS, IAM)
