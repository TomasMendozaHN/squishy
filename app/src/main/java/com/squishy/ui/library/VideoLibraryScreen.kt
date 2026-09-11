package com.squishy.ui.library

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.ViewList
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import androidx.core.content.PermissionChecker
import androidx.lifecycle.viewmodel.compose.viewModel
import com.squishy.compression.CompressionSettings
import com.squishy.data.VideoRepository
import com.squishy.history.HistoryEntry
import com.squishy.model.VideoFormat
import com.squishy.model.VideoItem
import com.squishy.model.VideoSortOrder
import com.squishy.model.VideoViewMode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun VideoLibraryScreen(viewModel: VideoLibraryViewModel? = null) {
    val context = LocalContext.current
    val application = context.applicationContext as android.app.Application
    val viewModel: VideoLibraryViewModel = viewModel ?: viewModel {
        VideoLibraryViewModel(application, VideoRepository(application))
    }
    val state by viewModel.state.collectAsState()
    val videos by viewModel.visibleVideos.collectAsState()
    val folders by viewModel.folders.collectAsState()
    val selectedFolder by viewModel.selectedFolder.collectAsState()
    val sortOrder by viewModel.sortOrder.collectAsState()
    val viewMode by viewModel.viewMode.collectAsState()
    var pendingCompress by remember { mutableStateOf<List<VideoItem>?>(null) }
    var pendingSettings by remember { mutableStateOf(CompressionSettings.DEFAULT) }
    var pendingDelete by remember { mutableStateOf(false) }
    var showOptionsSheet by remember { mutableStateOf(false) }
    var busyDialogVisible by remember { mutableStateOf(false) }
    var logsDialogVisible by remember { mutableStateOf(false) }
    var historyDialogVisible by remember { mutableStateOf(false) }
    val notificationLauncher =
        androidx.activity.compose.rememberLauncherForActivityResult(
            contract = androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
        ) {
            pendingCompress?.let {
                viewModel.compress(it, pendingSettings, pendingDelete)
            }
            pendingCompress = null
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

    var selectionMode by remember { mutableStateOf(false) }
    val selected = remember { mutableStateMapOf<Long, VideoItem>() }

    fun toggleSelection(video: VideoItem) {
        if (selected.containsKey(video.id)) selected.remove(video.id) else selected[video.id] = video
        if (selected.isEmpty()) selectionMode = false
    }

    fun enterSelectionMode(video: VideoItem) {
        selectionMode = true
        selected[video.id] = video
    }

    fun beginCompression(videos: List<VideoItem>) {
        if (videos.isEmpty()) return
        if (viewModel.compressionJobState.value != null || viewModel.queue.value.isNotEmpty()) {
            busyDialogVisible = true
            return
        }
        pendingCompress = videos
        showOptionsSheet = true
    }

    fun startCompression(settings: CompressionSettings, deleteOriginal: Boolean) {
        showOptionsSheet = false
        pendingCompress?.let { toCompress ->
            pendingSettings = settings
            pendingDelete = deleteOriginal
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PermissionChecker.PERMISSION_GRANTED
            ) {
                notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            } else {
                viewModel.compress(toCompress, settings, deleteOriginal)
            }
        }
    }

    fun compressSelected() {
        val toCompress = selected.values.toList()
        selected.clear()
        selectionMode = false
        beginCompression(toCompress)
    }

    Scaffold(
        topBar = {
            if (selectionMode) {
                TopAppBar(
                    title = { Text("${selected.size} selected") },
                    navigationIcon = {
                        TextButton(onClick = {
                            selected.clear()
                            selectionMode = false
                        }) { Text("Clear") }
                    },
                    actions = {
                        Button(
                            onClick = { compressSelected() },
                            enabled = selected.isNotEmpty()
                        ) { Text("Compress") }
                    }
                )
            } else {
                TopAppBar(
                    title = { Text("Videos") },
                    actions = {
                        FolderMenu(
                            folders = folders,
                            current = selectedFolder,
                            onSelect = viewModel::setFolder
                        )
                        SortMenu(current = sortOrder, onSelect = viewModel::sort)
                        TextButton(onClick = { viewModel.toggleViewMode() }) {
                            Icon(
                                imageVector = if (viewMode == VideoViewMode.LIST) {
                                    Icons.Filled.Apps
                                } else {
                                    Icons.Filled.ViewList
                                },
                                contentDescription = "Switch view"
                            )
                        }
                        TextButton(onClick = { historyDialogVisible = true }) {
                            Icon(Icons.Filled.History, contentDescription = "History")
                        }
                        TextButton(onClick = { logsDialogVisible = true }) { Text("Log") }
                    }
                )
            }
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
                val queue by viewModel.queue.collectAsState()
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                ) {
                    if (activeJob != null) {
                        CompressionStatusCard(
                            jobState = activeJob,
                            queueCount = queue.size,
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
                                text = if (selectedFolder != null) "No videos in this folder."
                                else "No videos found on this device.",
                                style = MaterialTheme.typography.bodyLarge
                            )
                        }
                    } else if (viewMode == VideoViewMode.GRID) {
                        LazyVerticalGrid(
                            columns = GridCells.Adaptive(minSize = 110.dp),
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(16.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(videos, key = { it.id }) { video ->
                                val isCompressing = activeJob?.job?.inputUri == video.uri
                                VideoGridItem(
                                    video = video,
                                    isCompressing = isCompressing,
                                    selectionMode = selectionMode,
                                    selected = selected.containsKey(video.id),
                                    onToggleSelected = { toggleSelection(video) },
                                    onLongPress = { enterSelectionMode(video) },
                                    onCompress = {
                                        if (!isCompressing) beginCompression(listOf(video))
                                    }
                                )
                            }
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
                                    selectionMode = selectionMode,
                                    selected = selected.containsKey(video.id),
                                    onToggleSelected = { toggleSelection(video) },
                                    onLongPress = { enterSelectionMode(video) },
                                    onCompress = {
                                        if (!isCompressing) {
                                            beginCompression(listOf(video))
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }

        if (showOptionsSheet) {
            CompressOptionsDialog(
                videos = pendingCompress.orEmpty(),
                onConfirm = { settings, deleteOriginal -> startCompression(settings, deleteOriginal) },
                onDismiss = { showOptionsSheet = false }
            )
        }

        if (busyDialogVisible) {
            BusyDialog(onDismiss = { busyDialogVisible = false })
        }

        if (logsDialogVisible) {
            LogsDialog(
                viewModel = viewModel,
                onDismiss = { logsDialogVisible = false }
            )
        }

        if (historyDialogVisible) {
            HistoryDialog(
                viewModel = viewModel,
                onDismiss = { historyDialogVisible = false }
            )
        }
    }
}

@Composable
private fun FolderMenu(folders: List<String>, current: String?, onSelect: (String?) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { expanded = true }) {
            Text(
                text = if (current == null) "Folder: All" else current.substringAfterLast('/'),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Icon(Icons.Filled.Folder, contentDescription = "Folder filter")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            DropdownMenuItem(
                text = { Text("All folders") },
                onClick = {
                    expanded = false
                    onSelect(null)
                }
            )
            folders.forEach { folder ->
                DropdownMenuItem(
                    text = { Text(folder) },
                    onClick = {
                        expanded = false
                        onSelect(folder)
                    }
                )
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

private data class QualityOption(val title: String, val settings: CompressionSettings)

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun CompressOptionsDialog(
    videos: List<VideoItem>,
    onConfirm: (CompressionSettings, Boolean) -> Unit,
    onDismiss: () -> Unit
) {
    var selected by remember { mutableStateOf(CompressionSettings.DEFAULT) }
    var deleteOriginal by remember { mutableStateOf(false) }
    val qualities = remember {
        listOf(
            QualityOption("Original (smaller file)", CompressionSettings.ORIGINAL),
            QualityOption("480p (smallest)", CompressionSettings.QUALITY_480P),
            QualityOption("720p (balanced)", CompressionSettings.QUALITY_720P),
            QualityOption("1080p (best)", CompressionSettings.QUALITY_1080P)
        )
    }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp)) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Compress ${if (videos.size == 1) "video" else "${videos.size} videos"}",
                    style = MaterialTheme.typography.titleMedium
                )
                qualities.forEach { option ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                            .combinedClickable(onClick = { selected = option.settings }),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = selected == option.settings,
                            onClick = { selected = option.settings }
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = option.title,
                                style = MaterialTheme.typography.bodyLarge
                            )
                            Text(
                                text = "Est. ${estimateOutputText(videos, option.settings)}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(
                        checked = deleteOriginal,
                        onCheckedChange = { deleteOriginal = it }
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Delete original after success",
                            style = MaterialTheme.typography.bodyLarge
                        )
                        Text(
                            text = "Permanently removes the source video once compression finishes. The original is kept if it fails.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDismiss) { Text("Cancel") }
                    TextButton(onClick = { onConfirm(selected, deleteOriginal) }) { Text("Compress") }
                }
            }
        }
    }
}

private fun estimateOutputText(videos: List<VideoItem>, settings: CompressionSettings): String {
    val totalBits = videos.sumOf { video ->
        (settings.targetVideoBitrateBps + 128_000) * (video.durationMs / 1000L).coerceAtLeast(1L)
    }
    return "${VideoFormat.formatSize(totalBits / 8L)} total"
}

@Composable
private fun BusyDialog(onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp)) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Compression already in progress",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "Stop the current compression before starting a new one.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDismiss) { Text("OK") }
                }
            }
        }
    }
}

@Composable
private fun historyTimestamp(ms: Long): String =
    SimpleDateFormat("d MMM yyyy, HH:mm", Locale.getDefault()).format(Date(ms))

@Composable
private fun HistoryDialog(
    viewModel: VideoLibraryViewModel,
    onDismiss: () -> Unit
) {
    val entries by viewModel.history.collectAsState()
    LaunchedEffect(Unit) {
        viewModel.loadHistory()
    }
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Card(modifier = Modifier.fillMaxWidth().fillMaxHeight(0.85f).padding(16.dp)) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Compression history",
                    style = MaterialTheme.typography.titleMedium
                )
                if (entries.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No compression history yet.",
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                } else {
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState())
                    ) {
                        entries.forEach { entry ->
                            HistoryRow(entry)
                            Spacer(modifier = Modifier.height(4.dp))
                        }
                    }
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = { viewModel.clearHistory() }) { Text("Clear") }
                    TextButton(onClick = onDismiss) { Text("Close") }
                }
            }
        }
    }
}

@Composable
private fun HistoryRow(entry: HistoryEntry) {
    val success = entry.status == "COMPLETED"
    val failed = entry.status == "FAILED"
    val statusColor = when {
        success -> Color(0xFF2E7D32)
        failed -> Color(0xFFC62828)
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    val statusLabel = when {
        success -> "Succeeded"
        failed -> "Failed"
        else -> "Stopped"
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = if (success) Icons.Filled.CheckCircle else Icons.Filled.PlayArrow,
            contentDescription = statusLabel,
            tint = statusColor
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(start = 8.dp)
        ) {
            Text(
                text = entry.displayName,
                style = MaterialTheme.typography.titleSmall,
                color = statusColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = buildString {
                    append(historyTimestamp(entry.finishedAt))
                    append("  •  took ")
                    append(VideoFormat.formatDuration(entry.durationMs))
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (!entry.detail.isNullOrBlank()) {
                Text(
                    text = entry.detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = statusColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
private fun LogsDialog(
    viewModel: VideoLibraryViewModel,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    var logText by remember { mutableStateOf(viewModel.viewLogs()) }
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Card(modifier = Modifier.fillMaxWidth().fillMaxHeight(0.85f).padding(16.dp)) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Logs",
                    style = MaterialTheme.typography.titleMedium
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .padding(8.dp)
                ) {
                    Text(
                        text = logText.ifEmpty { "No logs yet." },
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.verticalScroll(rememberScrollState())
                    )
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = { logText = viewModel.viewLogs() }) { Text("Refresh") }
                    TextButton(
                        onClick = {
                            val clipboard =
                                context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(
                                ClipData.newPlainText("squishy log", logText)
                            )
                            onDismiss()
                        }
                    ) { Text("Copy") }
                    TextButton(onClick = onDismiss) { Text("Close") }
                }
            }
        }
    }
}

@Composable
private fun CompressionStatusCard(
    jobState: com.squishy.compression.CompressionJobState,
    queueCount: Int,
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
                            text = if (queueCount > 0) {
                                "${jobState.progress}% · $queueCount in queue"
                            } else {
                                "${jobState.progress}%"
                            },
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
private fun VideoThumbnail(uri: String, modifier: Modifier) {
    val context = LocalContext.current
    var bitmap by remember(uri) { mutableStateOf<Bitmap?>(null) }
    var failed by remember(uri) { mutableStateOf(false) }
    LaunchedEffect(uri) {
        bitmap = null
        failed = false
        val bmp = withContext(Dispatchers.IO) {
            try {
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(context, Uri.parse(uri))
                    retriever.frameAtTime
                } finally {
                    try {
                        retriever.release()
                    } catch (_: Throwable) {
                    }
                }
            } catch (_: Throwable) {
                null
            }
        }
        if (bmp == null) {
            failed = true
        } else {
            bitmap = bmp
        }
    }
    val currentBitmap = bitmap
    Box(modifier = modifier.background(MaterialTheme.colorScheme.surfaceVariant)) {
        when {
            currentBitmap != null -> Image(
                bitmap = currentBitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
            failed -> Icon(
                imageVector = Icons.Filled.PlayArrow,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp)
                    .align(Alignment.Center),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            else -> CircularProgressIndicator(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp)
                    .align(Alignment.Center),
                strokeWidth = 2.dp
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun VideoGridItem(
    video: VideoItem,
    isCompressing: Boolean,
    onCompress: () -> Unit,
    selectionMode: Boolean = false,
    selected: Boolean = false,
    onToggleSelected: () -> Unit = {},
    onLongPress: () -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .combinedClickable(
                onClick = {
                    if (selectionMode) onToggleSelected() else onCompress()
                },
                onLongClick = {
                    if (!selectionMode) onLongPress()
                }
            )
    ) {
        Box {
            VideoThumbnail(
                uri = video.uri,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 90.dp, max = 180.dp)
            )
            if (selectionMode) {
                Checkbox(
                    checked = selected,
                    onCheckedChange = { onToggleSelected() },
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(4.dp)
                )
            }
            if (isCompressing) {
                CircularProgressIndicator(
                    modifier = Modifier
                        .align(Alignment.Center)
                        .height(24.dp),
                    strokeWidth = 2.dp
                )
            }
        }
        Text(
            text = video.displayName,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            text = "${VideoFormat.formatSize(video.sizeBytes)} • ${VideoFormat.formatDuration(video.durationMs)}",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun VideoRow(
    video: VideoItem,
    isCompressing: Boolean,
    onCompress: () -> Unit,
    selectionMode: Boolean = false,
    selected: Boolean = false,
    onToggleSelected: () -> Unit = {},
    onLongPress: () -> Unit = {}
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .combinedClickable(
                onClick = {
                    if (selectionMode) onToggleSelected() else onCompress()
                },
                onLongClick = {
                    if (!selectionMode) onLongPress()
                }
            ),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (selectionMode) {
            Checkbox(
                checked = selected,
                onCheckedChange = { onToggleSelected() }
            )
        }
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
