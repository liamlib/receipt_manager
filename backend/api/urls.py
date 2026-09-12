from rest_framework.routers import DefaultRouter
from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import (
	AccountViewSet,
	ReceiptViewSet,
	gmail_auth_start,
	gmail_auth_callback,
	gmail_status,
	gmail_disconnect,
	google_connect_page,
	show_receipt_emails,
)

router = DefaultRouter()
router.register("account", AccountViewSet, basename="account")
router.register("receipts", ReceiptViewSet, basename="receipts")

urlpatterns = router.urls + [
	path("token/", TokenObtainPairView.as_view(), name="token-obtain-pair"),
	path("token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
	path("google/start/", gmail_auth_start, name="google-start"),
	path("google/callback/", gmail_auth_callback, name="google-callback"),
	path("google/status/", gmail_status, name="google-status"),
	path("google/disconnect/", gmail_disconnect, name="google-disconnect"),
	path("google/connect/", google_connect_page, name="google-connect"),
	path("google/emails/", show_receipt_emails, name="google-emails"),
]
