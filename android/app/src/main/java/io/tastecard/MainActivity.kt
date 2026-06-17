package io.tastecard

import android.Manifest
import android.os.Build
import android.os.Bundle
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
        val granted = result[Manifest.permission.READ_MEDIA_IMAGES] == true ||
            result[Manifest.permission.READ_EXTERNAL_STORAGE] == true ||
            result["android.permission.READ_MEDIA_VISUAL_USER_SELECTED"] == true
        vm.onPermissionResult(granted)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Box(Modifier.fillMaxSize()) {
                    Root(vm) { permissionLauncher.launch(requiredPermissions()) }
                    vm.toast?.let { msg ->
                        Box(Modifier.fillMaxSize().padding(top = 48.dp), contentAlignment = Alignment.TopCenter) {
                            ToastBar(msg)
                        }
                    }
                }
            }
        }
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
private fun Root(vm: TastecardViewModel, requestPermission: () -> Unit) {
    when (val p = vm.phase) {
        is Phase.Greeting -> GreetingScreen(onStart = vm::begin)
        is Phase.Priming -> PrimingScreen(onContinue = requestPermission, onBack = vm::goGreeting)
        is Phase.Generating -> GeneratingScreen(vm)
        is Phase.CardReady -> vm.card?.let { CardScreen(vm, it) } ?: GreetingScreen(onStart = vm::begin)
        is Phase.WarmingUp -> WarmingUpScreen(p.scanned, onRetry = vm::startAnalysis, onBack = vm::goGreeting)
        is Phase.Denied -> DeniedScreen(onBack = vm::goGreeting)
        is Phase.Setup -> SetupScreen(p.message, onBack = vm::goGreeting)
    }
}
