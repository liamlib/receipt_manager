from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.exceptions import PermissionDenied
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import User
from receipts.models import Receipt

from .serializers import (
    UserCreateSerializer,
    UserProfileSerializer,
    ReceiptSerializer,
    #BulkReceiptSerializer
    #UserCreateSerializer, 
    #UserProfileSerializer
)

from .permissions import BlockUnusedMethods


class AccountViewSet(viewsets.GenericViewSet):

    queryset = User.objects.all()

    # choose serializer based on action
    def get_serializer_class(self):
        if self.action == "create":
            return UserCreateSerializer
        return UserProfileSerializer

    # permissions
    def get_permissions(self):

        if self.action == "create":
            return [AllowAny()]

        return [IsAuthenticated()]

    # -------------------------
    # CREATE ACCOUNT
    # -------------------------
    def create(self, request):

        serializer = UserCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "user": UserProfileSerializer(user).data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
            status=status.HTTP_201_CREATED,
        )

    # -------------------------
    # GET CURRENT USER
    # -------------------------
    @action(detail=False, methods=["get"], url_path="me")
    def me(self, request):

        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data)

    # -------------------------
    # UPDATE CURRENT USER
    # -------------------------
    @me.mapping.patch
    def update_me(self, request):

        serializer = UserProfileSerializer(
            request.user,
            data=request.data,
            partial=True
        )

        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(serializer.data)

# -------------------------
# RECEIPTS
# -------------------------

class ReceiptViewSet(viewsets.ModelViewSet):
    serializer_class = ReceiptSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return Receipt.objects.none()
        return Receipt.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save()

    def create(self, request, *args, **kwargs):
        if not request.user.is_authenticated:
            raise PermissionDenied("Authentication credentials were not provided.")

        # bulk create
        if isinstance(request.data, list):
            serializer = self.get_serializer(data=request.data, many=True)
            serializer.is_valid(raise_exception=True)
            receipts = serializer.save()   # <-- remove user=request.user
            return Response(
                self.get_serializer(receipts, many=True).data,
                status=status.HTTP_201_CREATED
            )

        return super().create(request, *args, **kwargs)
#-------------------------
# GOOGLE OAUTH
#-------------------------
from django.conf import settings
from django.core import signing
from django.http import JsonResponse
from django.shortcuts import redirect, render
from google_auth_oauthlib.flow import Flow
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
import requests

from google.auth.transport.requests import Request

from accounts.models import User

GOOGLE_CLIENT_ID = getattr(settings, "GOOGLE_CLIENT_ID", None)
GOOGLE_CLIENT_SECRET = getattr(settings, "GOOGLE_CLIENT_SECRET", None)
GOOGLE_REDIRECT_URI = getattr(settings, "GOOGLE_REDIRECT_URI", None)
GOOGLE_OAUTH_STATE_SALT = "gmail-oauth-state"
GOOGLE_OAUTH_STATE_MAX_AGE = 10 * 60

SCOPES = [
    "openid",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/userinfo.profile",
    "https://www.googleapis.com/auth/gmail.readonly",
]

def build_google_flow(state=None):
    flow = Flow.from_client_config(
        {
            "web": {
                "client_id": GOOGLE_CLIENT_ID,
                "client_secret": GOOGLE_CLIENT_SECRET,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
            }
        },
        scopes=SCOPES,
        state=state,
    )
    flow.redirect_uri = GOOGLE_REDIRECT_URI
    return flow


def make_google_oauth_state(user):
    return signing.dumps(
        {"user_id": user.pk},
        salt=GOOGLE_OAUTH_STATE_SALT,
        compress=True,
    )


def read_google_oauth_state(raw_state):
    return signing.loads(
        raw_state,
        salt=GOOGLE_OAUTH_STATE_SALT,
        max_age=GOOGLE_OAUTH_STATE_MAX_AGE,
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def gmail_auth_start(request):
    flow = build_google_flow()
    signed_state = make_google_oauth_state(request.user)
    authorization_url, state = flow.authorization_url(
        access_type="offline",
        include_granted_scopes="true",
        prompt="consent",
        state=signed_state,
    )

    return Response({"authorization_url": authorization_url, "state": state})

#--------------------------
#
#--------------------------
def gmail_auth_callback(request):
    raw_state = request.GET.get("state")
    if not raw_state:
        return JsonResponse({"ok": False, "error": "Missing OAuth state"}, status=400)

    try:
        state_data = read_google_oauth_state(raw_state)
        user = User.objects.get(pk=state_data["user_id"])
    except (signing.BadSignature, signing.SignatureExpired, KeyError, User.DoesNotExist):
        return JsonResponse({"ok": False, "error": "Invalid or expired OAuth state"}, status=400)

    flow = build_google_flow(state=raw_state)
    flow.fetch_token(authorization_response=request.build_absolute_uri())

    creds = flow.credentials

    # Get user profile info
    profile = requests.get(
        "https://openidconnect.googleapis.com/v1/userinfo",
        headers={"Authorization": f"Bearer {creds.token}"},
        timeout=20,
    ).json()

    user.google_sub = profile.get("sub")
    if not user.first_name:
        user.first_name = profile.get("given_name", "")
    if not user.last_name:
        user.last_name = profile.get("family_name", "")
    user.access_token = creds.token
    if creds.refresh_token:
        user.refresh_token = creds.refresh_token
    user.token_uri = creds.token_uri
    user.client_id = creds.client_id or GOOGLE_CLIENT_ID
    user.client_secret = creds.client_secret or GOOGLE_CLIENT_SECRET
    user.scopes = " ".join(creds.scopes or [])
    user.token_expiry = creds.expiry
    user.save(update_fields=[
        "google_sub",
        "first_name",
        "last_name",
        "access_token",
        "refresh_token",
        "token_uri",
        "client_id",
        "client_secret",
        "scopes",
        "token_expiry",
        "updated_at",
    ])

    return render(request, "api/google_connected.html", {"email": profile.get("email")})

#-------------------------
#
#-------------------------

def get_gmail_service(user):
    # accept either a User instance or a primary key
    account = user if isinstance(user, User) else User.objects.get(pk=user)

    creds = Credentials(
        token=account.access_token,
        refresh_token=account.refresh_token,
        token_uri=account.token_uri,
        client_id=account.client_id or GOOGLE_CLIENT_ID,
        client_secret=account.client_secret or GOOGLE_CLIENT_SECRET,
        scopes=(account.scopes or "").split(),
    )

    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
        account.access_token = creds.token
        account.token_expiry = creds.expiry
        if getattr(creds, "refresh_token", None):
            account.refresh_token = creds.refresh_token
        account.save(update_fields=["access_token", "refresh_token", "token_expiry", "updated_at"])

    return build("gmail", "v1", credentials=creds)


# Simple frontend: page to connect Gmail and show matching emails
from .services.sync_gmail import fetch_receipt_emails

def google_connect_page(request):
    return render(request, "api/google_connect.html", {})

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def gmail_status(request):
    return Response({
        "connected": bool(request.user.refresh_token and "gmail.readonly" in (request.user.scopes or "")),
        "scopes": (request.user.scopes or "").split(),
        "token_expiry": request.user.token_expiry,
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def gmail_disconnect(request):
    request.user.google_sub = None
    request.user.access_token = None
    request.user.refresh_token = None
    request.user.scopes = ""
    request.user.token_expiry = None
    request.user.history_id = None
    request.user.save(update_fields=[
        "google_sub",
        "access_token",
        "refresh_token",
        "scopes",
        "token_expiry",
        "history_id",
        "updated_at",
    ])
    return Response({"ok": True, "connected": False})


@api_view(["POST", "GET"])
@permission_classes([IsAuthenticated])
def show_receipt_emails(request):
    service = get_gmail_service(request.user)
    emails = []
    try:
        emails = fetch_receipt_emails(service)
    except Exception as e:
        return Response({"ok": False, "error": str(e)}, status=500)

    return Response({"ok": True, "emails": emails})
