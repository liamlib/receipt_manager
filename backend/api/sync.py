# sync.py
RECEIPT_QUERY = (
    '(subject:receipt OR subject:"your order" OR subject:invoice OR subject:"order confirmation" '
    'OR "thank you for your purchase" OR "payment received" OR "order total") '
    '-category:promotions'
)

def list_receipt_message_ids(service, page_token=None):
    resp = service.users().messages().list(
        userId="me",
        q=RECEIPT_QUERY,
        maxResults=100,
        pageToken=page_token,
    ).execute()

    messages = resp.get("messages", [])
    next_token = resp.get("nextPageToken")
    return messages, next_token

def get_message(service, message_id):
    return service.users().messages().get(
        userId="me",
        id=message_id,
        format="full",
    ).execute()