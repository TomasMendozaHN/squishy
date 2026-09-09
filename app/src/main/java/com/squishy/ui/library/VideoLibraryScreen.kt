package com.squishy.ui.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.content.PermissionChecker
import androidx.lifecycle.viewmodel.compose.viewModel
import com.squishy.data.VideoRepository
import com.squishy.model.VideoFormat
import com.squishy.model.VideoItem
import com.squishy.model.VideoSortOrder
import android.Manifest

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VideoLibraryScreen(viewModel: VideoLibraryViewModel? = null) {
    val context = LocalContext.current
    val viewModel: VideoLibraryViewModel = viewModel ?: viewModel {
        VideoLibraryViewModel(VideoRepository(context.applicationContext))
    }
    val state by viewModel.state.collectAsState()
    val videos by viewModel.sortedVideos.collectAsState()
    val sortOrder by viewModel.sortOrder.collectAsState()

    LaunchedEffect(state) {
        if (state is VideoLibraryViewModel.State.Ready &&
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_MEDIA_VIDEO
            ) != PermissionChecker.PERMISSION_GRANTED
        ) {
            viewModel.permissionNeeded()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Videos") },
                actions = { SortMenu(current = sortOrder, onSelect = viewModel::sort) }
            )
        }
    ) { padding ->
        when (state) {
            is VideoLibraryViewModel.State.Loading -> Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }

            is VideoLibraryViewModel.State.PermissionNeeded -> PermissionRequest(
                modifier = Modifier.padding(padding),
                onGranted = {
                    viewModel.permissionGranted()
                }
            )

            is VideoLibraryViewModel.State.Ready -> if (videos.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No videos found on this device.",
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(videos, key = { it.id }) { video ->
                        VideoRow(video)
                    }
                }
            }
        }
    }
}

@Composable
private fun SortMenu(current: VideoSortOrder, onSelect: (VideoSortOrder) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { expanded = true }) {
            Text(text = "Sort: ${current.label}")
            Icon(Icons.Filled.ArrowDropDown, contentDescription = "Sort options")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            VideoSortOrder.entries.forEach { order ->
                DropdownMenuItem(
                    text = { Text(order.label) },
                    onClick = {
                        expanded = false
                        onSelect(order)
                    }
                )
            }
        }
    }
}

@Composable
private fun VideoRow(video: VideoItem) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Filled.PlayArrow,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(start = 12.dp)
        ) {
            Text(
                text = video.displayName,
                style = MaterialTheme.typography.titleSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = buildString {
                    append(VideoFormat.formatSize(video.sizeBytes))
                    append("  •  ")
                    append(VideoFormat.formatDuration(video.durationMs))
                    append("  •  ")
                    append(VideoFormat.formatDate(video.dateModified))
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun PermissionRequest(modifier: Modifier = Modifier, onGranted: () -> Unit) {
    val context = LocalContext.current
    val launcher = androidx.activity.compose.rememberLauncherForActivityResult(
        contract = androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) onGranted()
    }

    LaunchedEffect(Unit) {
        launcher.launch(Manifest.permission.READ_MEDIA_VIDEO)
    }

    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "Permission to read videos is required to show your library.",
            style = MaterialTheme.typography.bodyLarge
        )
        TextButton(
            onClick = { launcher.launch(Manifest.permission.READ_MEDIA_VIDEO) },
            modifier = Modifier.padding(top = 12.dp)
        ) {
            Text("Grant permission")
        }
    }
}
