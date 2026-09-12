from rest_framework.permissions import BasePermission


class BlockUnusedMethods(BasePermission):

    allowed_methods = []

    def has_permission(self, request, view):
        if request.method in self.allowed_methods:
            return True
        return False