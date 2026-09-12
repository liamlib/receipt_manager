from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.utils import timezone


# Create your models here.
class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("Users must have an email address")

        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        return self.create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    class Gender(models.TextChoices):
        male = "male", "Male"
        female = "female", "Female"


        
    google_sub = models.CharField(max_length=255, blank=True, null=True)
    first_name = models.CharField(max_length = 100, blank = True)
    last_name = models.CharField(max_length = 100, blank = True)
    email = models.EmailField(max_length = 100, unique = True)
    phone = models.CharField(max_length=40, blank=True, default="")
    address = models.TextField(blank=True, default="")
    currency = models.CharField(max_length=10, blank=True, default="USD")
    profile_image = models.TextField(blank=True, default="")
    date_of_birth = models.DateField(null = True, blank = True)
    gender = models.CharField(max_length = 10 ,choices = Gender.choices ,null = True, blank = True)
    is_active = models.BooleanField(default = True)
    is_staff = models.BooleanField(default = False)

    date_joined = models.DateTimeField(default = timezone.now)
    access_token = models.TextField(blank=True, null=True)
    refresh_token = models.TextField(blank=True, null=True)
    token_uri = models.CharField(max_length=255, default="https://oauth2.googleapis.com/token")
    client_id = models.CharField(max_length=255, blank=True, default="")
    client_secret = models.CharField(max_length=255, blank=True, default="")
    scopes = models.TextField(blank=True, default="")
    token_expiry = models.DateTimeField(blank=True, null=True)
    history_id = models.CharField(max_length=255, blank=True, null=True)  # for incremental sync later
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    objects = UserManager()
    USERNAME_FIELD = "email"
    def __str__ (self):
        return self.email

    def has_perm(self, perm, obj=None):
        return self.is_superuser or self.is_staff

    def has_module_perms(self, app_label):
        return self.is_superuser or self.is_staff
        
    # A last_name 100 characters long also can be blank 
    # Email it uses models.EmailField and unique = true

    
