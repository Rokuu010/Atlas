package io.tastecard

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import io.tastecard.ui.CardScreen
import io.tastecard.ui.DeniedScreen
import io.tastecard.ui.GeneratingScreen
import io.tastecard.ui.GreetingScreen
import io.tastecard.ui.Phase
import io.tastecard.ui.PrimingScreen
import io.tastecard.ui.SetupScreen
import io.tastecard.ui.TastecardViewModel
import io.tastecard.ui.ToastBar
import io.tastecard.ui.WarmingUpScreen

class MainActivity : ComponentActivity() {

    private val vm: TastecardViewModel by viewModels()

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        // Full access = the broad read permission (or legacy storage) is granted.
        val full = result[Manifest.permission.READ_MEDIA_IMAGES] == true ||
            result[Manifest.permission.READ_EXTERNAL_STORAGE] == true
        // Partial access (Android 14 "Select photos") grants ONLY the user-selected scope.
        val partial = result["android.permission.READ_MEDIA_VISUAL_USER_SELECTED"] == true
        vm.onPermissionResult(granted = full || partial, partial = partial && !full)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Box(Modifier.fillMaxSize()) {
                    Root(
                        vm = vm,
                        requestPermission = { permissionLauncher.launch(requiredPermissions()) },
                        openAppSettings = ::openAppSettings,
                    )
                    vm.toast?.let { msg ->
                        Box(Modifier.fillMaxSize().padding(top = 48.dp), contentAlignment = Alignment.TopCenter) {
                            ToastBar(msg)
                        }
                    }
                }
            }
        }
    }

    /** Opens this app's system settings page so the user can change a denied/limited grant. */
    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun requiredPermissions(): Array<String> = buildList {
        if (Build.VERSION.SDK_INT >= 33) {
            add(Manifest.permission.READ_MEDIA_IMAGES)
            if (Build.VERSION.SDK_INT >= 34) add("android.permission.READ_MEDIA_VISUAL_USER_SELECTED")
        } else {
            add(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        add(Manifest.permission.ACCESS_MEDIA_LOCATION)
    }.toTypedArray()
}

@Composable
private fun Root(
    vm: TastecardViewModel,
    requestPermission: () -> Unit,
    openAppSettings: () -> Unit,
) {
    when (val p = vm.phase) {
        is Phase.Greeting -> GreetingScreen(onStart = vm::begin)
        is Phase.Priming -> PrimingScreen(onContinue = requestPermission, onBack = vm::goGreeting)
        is Phase.Generating -> GeneratingScreen(vm)
        is Phase.CardReady -> vm.card?.let { CardScreen(vm, it) } ?: GreetingScreen(onStart = vm::begin)
        is Phase.WarmingUp -> WarmingUpScreen(
            reason = p.reason,
            scanned = p.scanned,
            partialAccess = vm.partialAccess,
            onRetry = vm::startAnalysis,
            // In partial mode, re-requesting re-opens the Android 14 "Select photos" sheet.
            onSelectMorePhotos = requestPermission,
            onBack = vm::goGreeting,
        )
        is Phase.Denied -> DeniedScreen(
            onOpenSettings = openAppSettings,
            onTryAgain = requestPermission,
            onBack = vm::goGreeting,
        )
        is Phase.Setup -> SetupScreen(p.message, onBack = vm::goGreeting)
    }
}
