import boto3
import json
import nltk
from nltk.sentiment import SentimentIntensityAnalyzer

nltk.download('vader_lexicon')

s3 = boto3.client("s3")
INPUT_BUCKET = "raw-comments-sa1-marcoabrantes"
OUTPUT_BUCKET = "results-sentiment-sa1-marcoabrantes"

analyzer = SentimentIntensityAnalyzer()

def analyze_sentiment(text):
    scores = analyzer.polarity_scores(text)
    compound = scores['compound']
    return compound

def process_files():
    print(f"Reading files from bucket: {INPUT_BUCKET}")
    
    response = s3.list_objects_v2(Bucket=INPUT_BUCKET)
    contents = response.get("Contents", [])

    if not contents:
        print("No files found in the input bucket.")
        return

    for obj in contents:
        key = obj["Key"]
        print(f"Processing file: {key}")

        s3_object = s3.get_object(Bucket=INPUT_BUCKET, Key=key)
        content = s3_object["Body"].read().decode("utf-8")

        comments = content.strip().splitlines()
        results = []

        for idx, comment in enumerate(comments, start=1):
            score = analyze_sentiment(comment)
            sentiment = (
                "positive" if score > 0.05
                else "negative" if score < -0.05
                else "neutral"
            )

            print(f"Comment {idx}: {sentiment}")
            results.append({
                "comment_number": idx,
                "text": comment,
                "compound_score": score,
                "sentiment": sentiment
            })

        # Save result JSON in the output bucket
        output_key = key.replace(".txt", ".json")

        s3.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=output_key,
            Body=json.dumps(results, indent=2)
        )

        print(f"Analysis saved to {OUTPUT_BUCKET}/{output_key}")

process_files()
