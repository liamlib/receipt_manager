from django.contrib import admin
from receipts.models import Receipt
from receipts.models import EmailMessage

# Register your models here.
admin.site.register(Receipt)
admin.site.register(EmailMessage)
