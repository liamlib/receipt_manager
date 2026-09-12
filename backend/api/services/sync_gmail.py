import base64

RECEIPT_QUERY = '(receipt OR invoice OR "order confirmation" OR "payment received" OR "thank you for your purchase")'


# 1. LIST messages
def list_messages(service):
    response = service.users().messages().list(
        userId="me",
        q=RECEIPT_QUERY,
        maxResults=10,
    ).execute()

    return response.get("messages", [])


# 2. GET full message
def get_message(service, message_id):
    return service.users().messages().get(
        userId="me",
        id=message_id,
        format="full",
    ).execute()


# 3. Decode base64
def decode_base64(data):
    if not data:
        return ""
    return base64.urlsafe_b64decode(data.encode("UTF-8")).decode("utf-8", errors="ignore")


# 4. Extract headers
def get_headers(message):
    headers = message["payload"]["headers"]
    return {h["name"].lower(): h["value"] for h in headers}


# 5. Extract body (handles nested parts)
def extract_body(payload):
    text = ""

    def walk(part):
        nonlocal text

        mime_type = part.get("mimeType", "")
        body = part.get("body", {})

        if mime_type == "text/plain" and body.get("data"):
            text += decode_base64(body["data"])

        # recurse into parts
        for p in part.get("parts", []):
            walk(p)

    walk(payload)
    return text


# 6. Normalize message
def normalize_message(message):
    headers = get_headers(message)
    body = extract_body(message.get("payload", {}))

    return {
        "id": message.get("id"),
        "subject": headers.get("subject", ""),
        "from": headers.get("from", ""),
        "date": headers.get("date", ""),
        "body": body,
    }


# 7. MAIN function (call this)
def fetch_receipt_emails(service):
    messages = list_messages(service)

    results = []

    for msg in messages:
        full = get_message(service, msg["id"])
        normalized = normalize_message(full)

        results.append(normalized)

    return results