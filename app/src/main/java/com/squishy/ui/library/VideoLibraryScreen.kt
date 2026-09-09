package com.squishy.ui.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.LinearProgressIndicator
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
import android.os.Build
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
    val application = context.applicationContext as android.app.Application
    val viewModel: VideoLibraryViewModel = viewModel ?: viewModel {
        VideoLibraryViewModel(application, VideoRepository(application))
    }
    val state by viewModel.state.collectAsState()
    val videos by viewModel.sortedVideos.collectAsState()
    val sortOrder by viewModel.sortOrder.collectAsState()
    var pendingVideo by remember { mutableStateOf<VideoItem?>(null) }
    val notificationLauncher =
        androidx.activity.compose.rememberLauncherForActivityResult(
            contract = androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
        ) {
            pendingVideo?.let { viewModel.compress(it) }
            pendingVideo = null
        }

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

            is VideoLibraryViewModel.State.Ready -> {
                val jobState by viewModel.compressionJobState.collectAsState()
                val activeJob = jobState
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                ) {
                    if (activeJob != null) {
                        CompressionStatusCard(
                            jobState = activeJob,
                            onStop = { viewModel.stopCompression() }
                        )
                    }
                    if (videos.isEmpty()) {
                        Box(
                            modifier = Modifier
                                .fillMaxSize(),
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
                                val isCompressing = activeJob?.job?.inputUri == video.uri
                                VideoRow(
                                    video = video,
                                    isCompressing = isCompressing,
                                    onCompress = {
                                        if (!isCompressing) {
                                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                                                ContextCompat.checkSelfPermission(
                                                    context,
                                                    Manifest.permission.POST_NOTIFICATIONS
                                                ) != PermissionChecker.PERMISSION_GRANTED
                                            ) {
                                                pendingVideo = video
                                                notificationLauncher.launch(
                                                    Manifest.permission.POST_NOTIFICATIONS
                                                )
                                            } else {
                                                viewModel.compress(video)
                                            }
                                        }
                                    }
                                )
                            }
                        }
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
private fun CompressionStatusCard(
    jobState: com.squishy.compression.CompressionJobState,
    onStop: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = jobState.job.displayName,
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                when (jobState.status) {
                    com.squishy.compression.CompressionStatus.RUNNING -> {
                        Text(
                            text = "${jobState.progress}%",
                            style = MaterialTheme.typography.titleSmall
                        )
                    }
                    com.squishy.compression.CompressionStatus.COMPLETED -> Text(
                        text = "Done",
                        style = MaterialTheme.typography.titleSmall
                    )
                    com.squishy.compression.CompressionStatus.FAILED -> Text(
                        text = "Failed",
                        style = MaterialTheme.typography.titleSmall
                    )
                    com.squishy.compression.CompressionStatus.CANCELLED -> Text(
                        text = "Stopped",
                        style = MaterialTheme.typography.titleSmall
                    )
                    com.squishy.compression.CompressionStatus.QUEUED -> Unit
                }
            }
            if (jobState.status == com.squishy.compression.CompressionStatus.RUNNING) {
                Spacer(modifier = Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { jobState.progress / 100f },
                    modifier = Modifier.fillMaxWidth()
                )
            }
            if (jobState.status == com.squishy.compression.CompressionStatus.RUNNING) {
                Button(
                    onClick = onStop,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp)
                ) {
                    Text("Stop")
                }
            }
        }
    }
}

@Composable
private fun VideoRow(
    video: VideoItem,
    isCompressing: Boolean,
    onCompress: () -> Unit
) {
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
        if (isCompressing) {
            CircularProgressIndicator(
                modifier = Modifier
                    .padding(start = 12.dp)
                    .height(20.dp),
                strokeWidth = 2.dp
            )
        } else {
            Button(
                onClick = onCompress,
                modifier = Modifier
                    .padding(start = 12.dp)
                    .height(36.dp)
            ) {
                Text("Compress")
            }
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
