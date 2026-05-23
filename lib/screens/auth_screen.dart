import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/app_session.dart';
import '../core/shared_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final loginEmail = TextEditingController();
  final loginPassword = TextEditingController();
  final name = TextEditingController();
  final registerEmail = TextEditingController();
  final registerPassword = TextEditingController();
  final forgotEmail = TextEditingController();
  int mode = 0;
  bool busy = false;
  bool hideLoginPassword = true;
  bool hideRegisterPassword = true;
  String? error;
  String? message;
  int _logoTapCount = 0;
  bool _showApiSettings = false;

  @override
  void dispose() {
    loginEmail.dispose();
    loginPassword.dispose();
    name.dispose();
    registerEmail.dispose();
    registerPassword.dispose();
    forgotEmail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 28 : 16,
                0,
                wide ? 28 : 16,
                16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _logoTapCount++;
                        if (_logoTapCount >= 5) {
                          _showApiSettings = !_showApiSettings;
                          _logoTapCount = 0;
                        }
                      });
                    },
                    child: _AuthBanner(wide: wide),
                  ),
                  SizedBox(height: 40),
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: double.infinity,
                      child: _authForm(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authForm(BuildContext context) {
    final title = switch (mode) {
      0 => 'Sign in',
      1 => 'Open your account',
      _ => 'Recover access',
    };
    final subtitle = switch (mode) {
      0 => 'Continue to your wallets, monthly totals, and goals.',
      1 => 'Create a profile and start tracking with clean defaults.',
      _ => 'Use your account email to receive a password reset link.',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 35,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (mode != 2) ...[
              const SizedBox(height: 22),
              _ModeSwitch(
                mode: mode,
                enabled: !busy,
                onChanged: (value) => setState(() {
                  mode = value;
                  error = null;
                  message = null;
                }),
              ),
            ],
            const SizedBox(height: 22),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    fit: StackFit.passthrough,
                    children: <Widget>[
                      ...previousChildren,
                      ?currentChild,
                    ],
                  );
                },
                child: Column(
                  key: ValueKey<int>(mode),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: switch (mode) {
                    0 => _loginFields(),
                    1 => _registerFields(),
                    _ => _forgotFields(),
                  },
                ),
              ),
            ),
            if (error != null) MessageBanner(text: error!, isError: true),
            if (message != null) MessageBanner(text: message!, isError: false),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: busy ? null : submit,
              icon: busy
                  ? const AppLoader(size: 20, color: Colors.white)
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(switch (mode) {
                0 => 'Continue',
                1 => 'Create account',
                _ => 'Send reset link',
              }),
            ),
            if (_showApiSettings) ...[
              const SizedBox(height: 14),
              _ApiSettingsButton(
                busy: busy,
                apiUrl: widget.session.apiBaseUrl,
                onPressed: () async {
                  final changed = await showApiBaseUrlDialog(
                    context,
                    widget.session,
                  );
                  if (!mounted || !changed) return;
                  setState(() {
                    error = null;
                    message = 'API URL updated. Please sign in again.';
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _loginFields() => [
    TextField(
      controller: loginEmail,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'Email address',
        prefixIcon: Icon(Icons.alternate_email_rounded),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: loginPassword,
      obscureText: hideLoginPassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onSubmitted: (_) {
        if (!busy) submit();
      },
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: hideLoginPassword ? 'Show password' : 'Hide password',
          onPressed: () =>
              setState(() => hideLoginPassword = !hideLoginPassword),
          icon: Icon(
            hideLoginPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    ),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: busy
            ? null
            : () => setState(() {
                mode = 2;
                error = null;
                message = null;
              }),
        child: const Text('Forgot my password?'),
      ),
    ),
  ];

  List<Widget> _registerFields() => [
    TextField(
      controller: name,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.name],
      decoration: const InputDecoration(
        labelText: 'Full name',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: registerEmail,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'Email address',
        prefixIcon: Icon(Icons.alternate_email_rounded),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: registerPassword,
      obscureText: hideRegisterPassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      onSubmitted: (_) {
        if (!busy) submit();
      },
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: hideRegisterPassword ? 'Show password' : 'Hide password',
          onPressed: () =>
              setState(() => hideRegisterPassword = !hideRegisterPassword),
          icon: Icon(
            hideRegisterPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    ),
  ];

  List<Widget> _forgotFields() => [
    TextField(
      controller: forgotEmail,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.email],
      onSubmitted: (_) {
        if (!busy) submit();
      },
      decoration: const InputDecoration(
        labelText: 'Account email',
        prefixIcon: Icon(Icons.mark_email_unread_outlined),
      ),
    ),
    const SizedBox(height: 8),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: busy
            ? null
            : () => setState(() {
                mode = 0;
                error = null;
                message = null;
              }),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back to login'),
      ),
    ),
  ];

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      if (mode == 0) {
        await widget.session.login(loginEmail.text.trim(), loginPassword.text);
      } else if (mode == 1) {
        await widget.session.register(
          name.text.trim(),
          registerEmail.text.trim(),
          registerPassword.text,
        );
      } else {
        await widget.session.api.forgotPassword(forgotEmail.text.trim());
        setState(
          () => message =
              'If the account exists, a password reset link was sent.',
        );
      }
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } on TimeoutException {
      setState(() => error = 'The API did not respond in time.');
    } catch (exception) {
      setState(
        () =>
            error = 'Could not reach the API at ${widget.session.apiBaseUrl}.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _AuthBanner extends StatelessWidget {
  const _AuthBanner({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/banner.png',
      fit: BoxFit.contain,
      alignment: Alignment.center,
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final int mode;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: mode == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _ModeTab(
                selected: mode == 0,
                enabled: enabled,
                icon: Icons.login_rounded,
                label: 'Login',
                onPressed: () => onChanged(0),
              ),
              _ModeTab(
                selected: mode == 1,
                enabled: enabled,
                icon: Icons.person_add_alt_rounded,
                label: 'Register',
                onPressed: () => onChanged(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.ink : AppColors.muted;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 200),
                tween: ColorTween(end: foreground),
                builder: (context, color, child) {
                  return Icon(icon, size: 18, color: color);
                },
              ),
              const SizedBox(width: 6),
              Flexible(
                child: TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 200),
                  tween: ColorTween(end: foreground),
                  builder: (context, color, child) {
                    return Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiSettingsButton extends StatelessWidget {
  const _ApiSettingsButton({
    required this.busy,
    required this.apiUrl,
    required this.onPressed,
  });

  final bool busy;
  final String apiUrl;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              apiUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 10),
          const Text('Change'),
        ],
      ),
    );
  }
}
