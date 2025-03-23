import os
import boto3

os.environ.get('HOME', '/home/marco/')

client = boto3.client("s3")
response = client.list_objects_v2(
    Bucket="raw-comments-ec2-sentiment-analyzer-sa-east-1-marcoabrantes",
)
print(response)
