import os
import boto3

home_dir = os.environ.get('HOME', '/home/marco/')

client = boto3.client("s3")

response = client.list_objects_v2(
    Bucket="raw-comments-sa1-marcoabrantes",
)

print(response)