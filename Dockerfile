# Imagem atualizada com versões sem CVEs críticos/altos conhecidos
FROM python:3.13-slim

WORKDIR /app

COPY . .

# Atualiza pacotes do sistema antes de instalar dependências
RUN apt-get update && apt-get upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# Versão atualizada do flask sem vulnerabilidades conhecidas
RUN pip install --no-cache-dir flask==3.1.1

# Roda como usuário não-root
RUN useradd -m appuser
USER appuser

CMD ["python", "app.py"]
