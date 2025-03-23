import boto3
import json

s3 = boto3.client("s3")

INPUT_BUCKET = "raw-comments-sa1-marcoabrantes"
OUTPUT_BUCKET = "results-sentiment-sa1-marcoabrantes"

def analyze_sentiment(text):
    # Simple sentiment analysis logic (replace with model if needed)
    if "good" in text.lower() or "positivo" in text.lower():
        return 1.0
    elif "bad" in text.lower() or "negativo" in text.lower():
        return -1.0
    else:
        return 0.0

def process_files():
    print(f"Listing files from bucket: {INPUT_BUCKET}")
    
    response = s3.list_objects_v2(Bucket=INPUT_BUCKET)
    contents = response.get("Contents", [])

    if not contents:
        print("No files found in the input bucket.")
        return

    for obj in contents:
        file_key = obj["Key"]
        print(f"Reading file: {file_key}")

        s3_object = s3.get_object(Bucket=INPUT_BUCKET, Key=file_key)
        file_content = s3_object["Body"].read().decode("utf-8")

        polarity = analyze_sentiment(file_content)
        sentiment = (
            "positive" if polarity > 0
            else "negative" if polarity < 0
            else "neutral"
        )

        result = {
            "file": file_key,
            "polarity": polarity,
            "sentiment": sentiment
        }

        output_key = file_key.replace(".txt", ".json")

        s3.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=output_key,
            Body=json.dumps(result)
        )

        print(f"Saved result to {OUTPUT_BUCKET}/{output_key}")

process_files()
