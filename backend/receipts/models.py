from django.db import models
from django.utils import timezone
from accounts.models import User 


class Receipt(models.Model):
    class Currencies(models.TextChoices):
        EUR = "eur", "EUR"
        USD = "usd", "USD"
        GBP = "gbp", "GBP"

        @property 
        def symbol(self):
            return {
                "eur":"€",
                "usd":"$",
                "gbp":"£"
            }[self.value]
        
    user = models.ForeignKey(to= User, on_delete= models.SET_NULL, related_name="receipts", null = True, blank = True)
    

        
    # Money: use DecimalField for currency amounts
    total = models.DecimalField(max_digits=10, decimal_places=2)

    # Optional: currency code like USD/EUR (keeps it flexible)
    currency = models.CharField(max_length=3,choices=Currencies.choices, default=Currencies.EUR)

    # Store / merchant info
    store_name = models.CharField(max_length=150, blank=True)
    store_address = models.CharField(max_length=255, blank=True)

    # When the purchase happened
    date_of_purchase = models.DateTimeField(default=timezone.now)

    # Optional receipt metadata
    receipt_number = models.CharField(max_length=80, blank=True)
    payment_method = models.CharField(max_length=50, blank=True)  # e.g., "Visa", "Cash"
    tax = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)

    # Items: simplest is a text field; better is JSONField if you want structured line-items
    items_text = models.TextField(blank=True)

    return_by_date = models.DateField(blank = True, null = True)

    # Useful system fields
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        store = self.store_name or "Unknown store"
        return f"{store} - {self.total} {self.currency} ({self.date_of_purchase.date()})"


from django.db import models


class EmailMessage(models.Model):
    """
    Stores the raw incoming email before parsing into Receipt + ReceiptItems.
    """

    # Basic metadata
    subject = models.CharField(max_length=255, blank=True, default="")
    from_email = models.EmailField(blank=True, default="")
    to_email = models.EmailField(blank=True, default="")
    message_id = models.CharField(max_length=255, blank=True, default="", db_index=True)

    # Full content (never use CharField for full email body)
    raw_text = models.TextField(blank=True, default="")
    raw_html = models.TextField(blank=True, default="")

    # Attachments (optional – if you later store files)
    #has_attachments = models.BooleanField(default=False)

    # Processing state
    is_processed = models.BooleanField(default=False)
    

    # Link to created receipt (if successfully parsed)
    receipt = models.ForeignKey(
        "receipts.Receipt",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="source_emails",
    )

    # System tracking
    received_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["message_id"]),
            models.Index(fields=["is_processed"]),
        ]

    def __str__(self):
        return f"{self.subject} from {self.from_email}"
