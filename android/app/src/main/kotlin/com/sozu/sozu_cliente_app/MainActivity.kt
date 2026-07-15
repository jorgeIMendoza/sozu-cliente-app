package com.sozu.sozu_cliente_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (no FlutterActivity): requerido por local_auth,
// cuyo BiometricPrompt de androidx necesita una FragmentActivity.
class MainActivity : FlutterFragmentActivity()
