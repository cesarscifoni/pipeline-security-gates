# Imagem antiga intencionalmente para demonstrar detecção de CVEs pelo Trivy
FROM python:3.9-slim

WORKDIR /app

COPY . .

RUN pip install flask==2.0.0

CMD ["python", "app.py"]
