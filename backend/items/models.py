from django.db import models
from receipts.models import Receipt


class Item(models.Model):
    receipt = models.ForeignKey(
        Receipt,
        on_delete=models.CASCADE,
        related_name="items",
        db_index=True,
    )

    item_code = models.CharField(max_length=64, blank=True, default="", db_index=True)
    description = models.CharField(max_length=255, blank=True, default="")
    item_type = models.CharField(max_length=100, blank=True, default="")
    quantity = models.DecimalField(max_digits=10, decimal_places=3, default=1)
    unit_price = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    tax_rate = models.DecimalField(max_digits=6, decimal_places=4, null=True, blank=True)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    line_total = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    is_returned = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        label = self.description or self.item_code or f"Item {self.pk}"
        return f"{label} (x{self.quantity})"

    def save(self, *args, **kwargs):
        if self.line_total is None and self.unit_price is not None and self.quantity is not None:
            subtotal = self.unit_price * self.quantity
            tax = self.tax_amount or 0
            discount = self.discount_amount or 0
            self.line_total = subtotal + tax - discount

        super().save(*args, **kwargs)