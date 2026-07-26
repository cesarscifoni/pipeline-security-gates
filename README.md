# Pipeline CI/CD com Security Gates

Pipeline DevSecOps com verificações de segurança automáticas antes do deploy.

## Security Gates

| Gate | Ferramenta | O que detecta |
|------|-----------|---------------|
| Secret Scan | Gitleaks | Senhas e tokens no código |
| IaC Scan | Checkov | Misconfigurations no Terraform |
| Container Scan | Trivy | CVEs críticos na imagem Docker |
| Deploy | — | Só executa se todos passarem |

## Como funciona

1. Push para qualquer branch dispara o pipeline
2. Os 3 jobs de segurança rodam em paralelo
3. Se qualquer gate falhar, o deploy é bloqueado
4. Deploy só acontece em push para `main` com todos os gates verdes

## Evidências

O pipeline foi testado com misconfigurations intencionais:
- Bucket S3 sem encryption → Checkov detecta e bloqueia
- Imagem Docker com CVEs → Trivy detecta e bloqueia
- Após correção → pipeline passa e deploy é liberado
