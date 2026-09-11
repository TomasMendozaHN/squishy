package com.squishy.ui.library

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.squishy.CrashLogger
import com.squishy.compression.CompressionJobState
import com.squishy.compression.CompressionSettings
import com.squishy.compression.CompressionService
import com.squishy.data.VideoRepository
import com.squishy.history.CompressionHistoryStore
import com.squishy.history.HistoryEntry
import com.squishy.model.VideoItem
import com.squishy.model.VideoSortOrder
import com.squishy.model.VideoViewMode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class VideoLibraryViewModel(
    application: Application,
    private val repository: VideoRepository
) : AndroidViewModel(application) {

    val compressionJobState: StateFlow<CompressionJobState?> =
        CompressionService.currentJobState

    val queue: StateFlow<List<CompressionJobState>> = CompressionService.queue

    sealed interface State {
        data object Loading : State
        data object PermissionNeeded : State
        data class Ready(val videos: List<VideoItem>) : State
    }

    private val _rawVideos = MutableStateFlow(emptyList<VideoItem>())
    val rawVideos: StateFlow<List<VideoItem>> = _rawVideos.asStateFlow()

    private val _sortOrder = MutableStateFlow(VideoSortOrder.DATE_MODIFIED)
    val sortOrder: StateFlow<VideoSortOrder> = _sortOrder.asStateFlow()

    private val _state = MutableStateFlow<State>(State.Loading)
    val state: StateFlow<State> = _state.asStateFlow()

    private val _selectedFolder = MutableStateFlow<String?>(null)
    val selectedFolder: StateFlow<String?> = _selectedFolder.asStateFlow()

    val folders: StateFlow<List<String>> =
        _rawVideos
            .map { items ->
                items.map { it.folder }
                    .filter { it.isNotBlank() }
                    .distinct()
                    .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it })
            }
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5_000),
                initialValue = emptyList()
            )

    private val _viewMode = MutableStateFlow(VideoViewMode.LIST)
    val viewMode: StateFlow<VideoViewMode> = _viewMode.asStateFlow()

    val visibleVideos: StateFlow<List<VideoItem>> =
        combine(_rawVideos, _sortOrder, _selectedFolder) { items, order, folder ->
            val filtered = if (folder == null) items
            else items.filter { it.folder == folder }
            filtered.sortedWith(order.comparator())
        }.stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = emptyList()
        )

    private val _history = MutableStateFlow<List<HistoryEntry>>(emptyList())
    val history: StateFlow<List<HistoryEntry>> = _history.asStateFlow()

    init {
        refresh()
        loadHistory()
        viewModelScope.launch {
            var lastTerminal: CompressionJobState? = null
            CompressionService.currentJobState.collect { state ->
                if (state != null && state.isTerminal && state != lastTerminal) {
                    lastTerminal = state
                    refresh()
                    loadHistory()
                }
            }
        }
    }

    fun refresh(silent: Boolean = false) {
        viewModelScope.launch(Dispatchers.IO) {
            if (!silent) _state.value = State.Loading
            val videos = repository.loadVideos()
            _rawVideos.value = videos
            if (!silent) _state.value = State.Ready(videos)
        }
    }

    fun permissionNeeded() {
        _state.value = State.PermissionNeeded
    }

    fun permissionGranted() {
        refresh()
    }

    fun sort(order: VideoSortOrder) {
        _sortOrder.value = order
    }

    fun setFolder(folder: String?) {
        _selectedFolder.value = folder
    }

    fun setViewMode(mode: VideoViewMode) {
        _viewMode.value = mode
    }

    fun toggleViewMode() {
        _viewMode.value = if (_viewMode.value == VideoViewMode.LIST) {
            VideoViewMode.GRID
        } else {
            VideoViewMode.LIST
        }
    }

    fun loadHistory() {
        viewModelScope.launch(Dispatchers.IO) {
            _history.value = CompressionHistoryStore.load(getApplication())
        }
    }

    fun clearHistory() {
        viewModelScope.launch(Dispatchers.IO) {
            CompressionHistoryStore.clear(getApplication())
            _history.value = emptyList()
        }
    }

    fun compress(
        video: VideoItem,
        settings: CompressionSettings = CompressionSettings.DEFAULT,
        deleteOriginal: Boolean = false
    ) {
        compress(listOf(video), settings, deleteOriginal)
    }

    fun compress(
        videos: List<VideoItem>,
        settings: CompressionSettings = CompressionSettings.DEFAULT,
        deleteOriginal: Boolean = false
    ) {
        if (videos.isEmpty()) return
        CompressionService.enqueueCompressing(getApplication(), videos, settings, deleteOriginal)
    }

    fun stopCompression() {
        CompressionService.stopCompressing(getApplication())
    }

    fun viewLogs(): String = CrashLogger.dump()

    fun clearLogs() {
        CrashLogger.clear()
    }
}
