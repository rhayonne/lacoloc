# Auth - Datasources

```dart
AuthService.signUp(email, password, type, fullName)
AuthService.signIn(email, password)
AuthService.logout()
AuthService.resetPassword(email)

UserManagementDatasource.createUser(email, fullName)  // Invite
UserManagementDatasource.setUserPassword(userId, newPassword)
```

**RLS**: Tipo do usuário vem de User_Types_Reference via trigger.
