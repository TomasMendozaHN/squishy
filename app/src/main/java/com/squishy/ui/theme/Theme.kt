package com.squishy.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.squishy.R

private val SquishyFontFamily = FontFamily(Font(R.font.squishy_font))

private val SquishyLightColors = lightColorScheme(
    primary = Color(0xFF6C5CE7),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFE4DEFF),
    onPrimaryContainer = Color(0xFF2A1E6B),
    secondary = Color(0xFF00B8A9),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFC9F5F0),
    onSecondaryContainer = Color(0xFF00443E),
    tertiary = Color(0xFFFF8FAB),
    onTertiary = Color(0xFF331021),
    background = Color(0xFFF6F5FF),
    onBackground = Color(0xFF1C1B29),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF1C1B29),
    surfaceVariant = Color(0xFFECE9FE),
    onSurfaceVariant = Color(0xFF4A4668),
    outline = Color(0xFF7A7598),
    error = Color(0xFFE5484D)
)

private val SquishyDarkColors = darkColorScheme(
    primary = Color(0xFFB3A6FF),
    onPrimary = Color(0xFF2A1E6B),
    primaryContainer = Color(0xFF4A3F9E),
    onPrimaryContainer = Color(0xFFE4DEFF),
    secondary = Color(0xFF4FE3D5),
    onSecondary = Color(0xFF00443E),
    secondaryContainer = Color(0xFF00695F),
    onSecondaryContainer = Color(0xFFC9F5F0),
    tertiary = Color(0xFFFFB3C7),
    onTertiary = Color(0xFF331021),
    background = Color(0xFF14131F),
    onBackground = Color(0xFFE5E3F4),
    surface = Color(0xFF1C1B29),
    onSurface = Color(0xFFE5E3F4),
    surfaceVariant = Color(0xFF2A2842),
    onSurfaceVariant = Color(0xFFC8C3E6),
    outline = Color(0xFF8F8AB2),
    error = Color(0xFFFFB4B8)
)

private val SquishyTypography = Typography(
    displaySmall = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.Bold, fontSize = 36.sp, lineHeight = 44.sp),
    headlineMedium = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.Bold, fontSize = 28.sp, lineHeight = 34.sp),
    headlineSmall = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.Bold, fontSize = 24.sp, lineHeight = 30.sp),
    titleLarge = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.Bold, fontSize = 22.sp, lineHeight = 28.sp),
    titleMedium = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, lineHeight = 24.sp),
    titleSmall = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, lineHeight = 22.sp),
    bodyLarge = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.Normal, fontSize = 16.sp, lineHeight = 24.sp),
    bodyMedium = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.Normal, fontSize = 14.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.Normal, fontSize = 12.sp, lineHeight = 16.sp),
    labelLarge = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, lineHeight = 20.sp),
    labelMedium = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.Medium, fontSize = 12.sp, lineHeight = 16.sp),
    labelSmall = TextStyle(fontFamily = SquishyFontFamily, fontWeight = FontWeight.Medium, fontSize = 11.sp, lineHeight = 16.sp)
)

private val SquishyShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(32.dp)
)

@Composable
fun SquishyTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> SquishyDarkColors
        else -> SquishyLightColors
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = SquishyTypography,
        shapes = SquishyShapes,
        content = content
    )
}
