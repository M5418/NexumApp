import 'package:flutter/material.dart';

class Translations {
  static const supportedCodes = ['en', 'fr', 'pt', 'es', 'de'];

  static const displayNames = {
    'en': 'English',
    'fr': 'Français',
    'pt': 'Português',
    'es': 'Español',
    'de': 'Deutsch',
  };

  static const flags = {
    'en': '🇺🇸',
    'fr': '🇫🇷',
    'pt': '🇵🇹',
    'es': '🇪🇸',
    'de': '🇩🇪',
  };

  static const supportedLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('pt'),
    Locale('es'),
    Locale('de'),
  ];

  static const map = <String, Map<String, String>>{
    'en': {
      'app.title': 'Nexum',

      'auth.welcome': 'Welcome',
      'auth.start_subtext': "Let's get started by filling out the form below",
      'auth.email': 'Email',
      'auth.password': 'Password',
      'auth.confirm_password': 'Confirm Password',
      'auth.terms_prefix': 'By signing up you agree to our ',
      'auth.terms': 'terms',
      'auth.conditions': 'conditions',
      'auth.privacy': 'privacy',
      'auth.sign_up': 'Sign Up',
      'auth.already_have_account': 'Already have an account? ',
      'auth.sign_in': 'Sign In',

      'errors.fill_all_fields': 'Please fill all fields',
      'errors.password_min': 'Password must be at least 8 characters',
      'errors.password_mismatch': 'Passwords do not match',
      'errors.unexpected_response': 'Unexpected response: missing token',
      'errors.sign_up_failed': 'Sign up failed',
      'errors.sign_up_failed_try': 'Sign up failed. Please try again.',

      'settings.title': 'Settings',
      'settings.section.personalization': 'Personalization & Preferences',
      'settings.section.account_security': 'Account & Security',
      'settings.nav.account_center': 'Account Center',
      'settings.nav.feed_preferences': 'Feed Preferences',
      'settings.nav.content_controls': 'Content Controls',
      'settings.nav.notification_preferences': 'Notification Preferences',
      'settings.nav.language_region': 'Language & Region',
      'settings.nav.privacy_visibility': 'Privacy & Visibility',
      'settings.nav.blocked_muted': 'Blocked & Muted Accounts',
      'settings.nav.security_login': 'Security & Login',
      'settings.nav.logout': 'Logout',

      'dialogs.logout.title': 'Log out?',
      'dialogs.logout.message': 'Are you sure you want to log out?',

      'settings.language_region.title': 'Language & Region',
      'settings.display_language': 'Display language',

      'common.cancel': 'Cancel',
      'common.logout': 'Logout',
      'common.back': 'Back',
    },
    'fr': {
      'app.title': 'Nexum',

      'auth.welcome': 'Bienvenue',
      'auth.start_subtext': 'Commençons par remplir le formulaire ci-dessous',
      'auth.email': 'E-mail',
      'auth.password': 'Mot de passe',
      'auth.confirm_password': 'Confirmer le mot de passe',
      'auth.terms_prefix': "En vous inscrivant, vous acceptez nos ",
      'auth.terms': "conditions d'utilisation",
      'auth.conditions': 'conditions',
      'auth.privacy': 'politique de confidentialité',
      'auth.sign_up': "S'inscrire",
      'auth.already_have_account': 'Vous avez déjà un compte ? ',
      'auth.sign_in': 'Se connecter',

      'errors.fill_all_fields': 'Veuillez remplir tous les champs',
      'errors.password_min': 'Le mot de passe doit contenir au moins 8 caractères',
      'errors.password_mismatch': 'Les mots de passe ne correspondent pas',
      'errors.unexpected_response': 'Réponse inattendue : jeton manquant',
      'errors.sign_up_failed': "Échec de l'inscription",
      'errors.sign_up_failed_try': "Échec de l'inscription. Veuillez réessayer.",

      'settings.title': 'Paramètres',
      'settings.section.personalization': 'Personnalisation et préférences',
      'settings.section.account_security': 'Compte et sécurité',
      'settings.nav.account_center': 'Centre des comptes',
      'settings.nav.feed_preferences': 'Préférences du fil',
      'settings.nav.content_controls': 'Contrôles de contenu',
      'settings.nav.notification_preferences': 'Préférences de notification',
      'settings.nav.language_region': 'Langue et région',
      'settings.nav.privacy_visibility': 'Confidentialité et visibilité',
      'settings.nav.blocked_muted': 'Comptes bloqués et masqués',
      'settings.nav.security_login': 'Sécurité et connexion',
      'settings.nav.logout': 'Déconnexion',

      'dialogs.logout.title': 'Se déconnecter ?',
      'dialogs.logout.message': 'Voulez-vous vraiment vous déconnecter ?',

      'settings.language_region.title': 'Langue et région',
      'settings.display_language': "Langue d'affichage",

      'common.cancel': 'Annuler',
      'common.logout': 'Déconnexion',
      'common.back': 'Retour',
    },
    'pt': {
      'app.title': 'Nexum',

      'auth.welcome': 'Bem-vindo',
      'auth.start_subtext': 'Vamos começar preenchendo o formulário abaixo',
      'auth.email': 'E-mail',
      'auth.password': 'Senha',
      'auth.confirm_password': 'Confirmar senha',
      'auth.terms_prefix': 'Ao se cadastrar, você concorda com nossos ',
      'auth.terms': 'termos de uso',
      'auth.conditions': 'condições',
      'auth.privacy': 'política de privacidade',
      'auth.sign_up': 'Cadastrar-se',
      'auth.already_have_account': 'Já tem uma conta? ',
      'auth.sign_in': 'Entrar',

      'errors.fill_all_fields': 'Preencha todos os campos',
      'errors.password_min': 'A senha deve ter pelo menos 8 caracteres',
      'errors.password_mismatch': 'As senhas não coincidem',
      'errors.unexpected_response': 'Resposta inesperada: token ausente',
      'errors.sign_up_failed': 'Falha no cadastro',
      'errors.sign_up_failed_try': 'Falha no cadastro. Tente novamente.',

      'settings.title': 'Configurações',
      'settings.section.personalization': 'Personalização e preferências',
      'settings.section.account_security': 'Conta e segurança',
      'settings.nav.account_center': 'Central da conta',
      'settings.nav.feed_preferences': 'Preferências do feed',
      'settings.nav.content_controls': 'Controles de conteúdo',
      'settings.nav.notification_preferences': 'Preferências de notificação',
      'settings.nav.language_region': 'Idioma e região',
      'settings.nav.privacy_visibility': 'Privacidade e visibilidade',
      'settings.nav.blocked_muted': 'Contas bloqueadas e silenciadas',
      'settings.nav.security_login': 'Segurança e login',
      'settings.nav.logout': 'Sair',

      'dialogs.logout.title': 'Sair?',
      'dialogs.logout.message': 'Tem certeza de que deseja sair?',

      'settings.language_region.title': 'Idioma e região',
      'settings.display_language': 'Idioma de exibição',

      'common.cancel': 'Cancelar',
      'common.logout': 'Sair',
      'common.back': 'Voltar',
    },
    'es': {
      'app.title': 'Nexum',

      'auth.welcome': 'Bienvenido',
      'auth.start_subtext': 'Comencemos completando el formulario a continuación',
      'auth.email': 'Correo electrónico',
      'auth.password': 'Contraseña',
      'auth.confirm_password': 'Confirmar contraseña',
      'auth.terms_prefix': 'Al registrarte, aceptas nuestros ',
      'auth.terms': 'términos de uso',
      'auth.conditions': 'condiciones',
      'auth.privacy': 'política de privacidad',
      'auth.sign_up': 'Registrarse',
      'auth.already_have_account': '¿Ya tienes una cuenta? ',
      'auth.sign_in': 'Iniciar sesión',

      'errors.fill_all_fields': 'Por favor, completa todos los campos',
      'errors.password_min': 'La contraseña debe tener al menos 8 caracteres',
      'errors.password_mismatch': 'Las contraseñas no coinciden',
      'errors.unexpected_response': 'Respuesta inesperada: falta el token',
      'errors.sign_up_failed': 'Registro fallido',
      'errors.sign_up_failed_try': 'El registro falló. Inténtalo de nuevo.',

      'settings.title': 'Configuración',
      'settings.section.personalization': 'Personalización y preferencias',
      'settings.section.account_security': 'Cuenta y seguridad',
      'settings.nav.account_center': 'Centro de cuentas',
      'settings.nav.feed_preferences': 'Preferencias del feed',
      'settings.nav.content_controls': 'Controles de contenido',
      'settings.nav.notification_preferences': 'Preferencias de notificación',
      'settings.nav.language_region': 'Idioma y región',
      'settings.nav.privacy_visibility': 'Privacidad y visibilidad',
      'settings.nav.blocked_muted': 'Cuentas bloqueadas y silenciadas',
      'settings.nav.security_login': 'Seguridad e inicio de sesión',
      'settings.nav.logout': 'Cerrar sesión',

      'dialogs.logout.title': '¿Cerrar sesión?',
      'dialogs.logout.message': '¿Estás seguro de que deseas cerrar sesión?',

      'settings.language_region.title': 'Idioma y región',
      'settings.display_language': 'Idioma de visualización',

      'common.cancel': 'Cancelar',
      'common.logout': 'Cerrar sesión',
      'common.back': 'Atrás',
    },
    'de': {
      'app.title': 'Nexum',

      'auth.welcome': 'Willkommen',
      'auth.start_subtext': 'Beginnen wir, indem wir das untenstehende Formular ausfüllen',
      'auth.email': 'E-Mail',
      'auth.password': 'Passwort',
      'auth.confirm_password': 'Passwort bestätigen',
      'auth.terms_prefix': 'Mit der Registrierung stimmst du unseren ',
      'auth.terms': 'Nutzungsbedingungen',
      'auth.conditions': 'Bedingungen',
      'auth.privacy': 'Datenschutzrichtlinie',
      'auth.sign_up': 'Registrieren',
      'auth.already_have_account': 'Du hast bereits ein Konto? ',
      'auth.sign_in': 'Anmelden',

      'errors.fill_all_fields': 'Bitte fülle alle Felder aus',
      'errors.password_min': 'Das Passwort muss mindestens 8 Zeichen lang sein',
      'errors.password_mismatch': 'Passwörter stimmen nicht überein',
      'errors.unexpected_response': 'Unerwartete Antwort: Token fehlt',
      'errors.sign_up_failed': 'Registrierung fehlgeschlagen',
      'errors.sign_up_failed_try': 'Registrierung fehlgeschlagen. Bitte versuche es erneut.',

      'settings.title': 'Einstellungen',
      'settings.section.personalization': 'Personalisierung und Präferenzen',
      'settings.section.account_security': 'Konto und Sicherheit',
      'settings.nav.account_center': 'Kontocenter',
      'settings.nav.feed_preferences': 'Feed-Einstellungen',
      'settings.nav.content_controls': 'Inhaltskontrollen',
      'settings.nav.notification_preferences': 'Benachrichtigungseinstellungen',
      'settings.nav.language_region': 'Sprache und Region',
      'settings.nav.privacy_visibility': 'Datenschutz und Sichtbarkeit',
      'settings.nav.blocked_muted': 'Blockierte und stummgeschaltete Konten',
      'settings.nav.security_login': 'Sicherheit und Anmeldung',
      'settings.nav.logout': 'Abmelden',

      'dialogs.logout.title': 'Abmelden?',
      'dialogs.logout.message': 'Möchtest du dich wirklich abmelden?',

      'settings.language_region.title': 'Sprache und Region',
      'settings.display_language': 'Anzeigesprache',

      'common.cancel': 'Abbrechen',
      'common.logout': 'Abmelden',
      'common.back': 'Zurück',
    },
  };
}