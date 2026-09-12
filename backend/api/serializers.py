from rest_framework import serializers
from accounts.models import User
from receipts.models import Receipt
from items.models import Item


class UserCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "password",
            "first_name",
            "last_name",
            "phone",
            "address",
            "currency",
            "profile_image",
            "date_of_birth",
            "gender",
        ]

    def create(self, validated_data):
        password = validated_data.pop("password")
        return User.objects.create_user(password=password, **validated_data)


class UserProfileSerializer(serializers.ModelSerializer):
    gmail_connected = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "first_name",
            "last_name",
            "phone",
            "address",
            "currency",
            "profile_image",
            "date_of_birth",
            "gender",
            "gmail_connected",
        ]
        read_only_fields = ["gmail_connected"]

    def get_gmail_connected(self, user):
        return bool(user.refresh_token and user.scopes and "gmail.readonly" in user.scopes)


class ItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = Item
        exclude = ["receipt"]


class ReceiptListSerializer(serializers.ListSerializer):
    def create(self, validated_data):
        user = self.context["request"].user
        receipts = []

        for receipt_data in validated_data:
            items_data = receipt_data.pop("items", [])
            receipt = Receipt.objects.create(user=user, **receipt_data)

            for item_data in items_data:
                Item.objects.create(receipt=receipt, **item_data)

            receipts.append(receipt)

        return receipts


class ReceiptSerializer(serializers.ModelSerializer):
    items = ItemSerializer(many=True, required=False)

    class Meta:
        model = Receipt
        fields = "__all__"
        read_only_fields = ["user"]
        list_serializer_class = ReceiptListSerializer

    def create(self, validated_data):
        user = self.context["request"].user
        items_data = validated_data.pop("items", [])
        receipt = Receipt.objects.create(user=user, **validated_data)

        for item_data in items_data:
            Item.objects.create(receipt=receipt, **item_data)

        return receipt
