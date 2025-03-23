FROM python:3.9-slim

WORKDIR /app
COPY . /app

COPY comentarios.txt /app/comentarios.txt

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8080

ENV AWS_REGION=sa-east-1 \
    BUCKET_RAW=raw-comments-ec2-sentiment-analyzer-sa-east-1-marcoabrantes \
    BUCKET_RESULTS=sentiment-results-ec2-sentiment-analyzer-sa-east-1-marcoabrantes

RUN adduser --disabled-password --gecos '' sentiment_analyzer_user
USER sentiment_analyzer_user

CMD ["python", "main.py"]