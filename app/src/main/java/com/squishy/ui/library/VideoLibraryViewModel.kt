package com.squishy.ui.library

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.squishy.compression.CompressionJobState
import com.squishy.compression.CompressionService
import com.squishy.data.VideoRepository
import com.squishy.model.VideoItem
import com.squishy.model.VideoSortOrder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
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

    val sortedVideos: StateFlow<List<VideoItem>> =
        combine(_rawVideos, _sortOrder) { items, order ->
            items.sortedWith(order.comparator())
        }.stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = emptyList()
        )

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch(Dispatchers.IO) {
            _state.value = State.Loading
            val videos = repository.loadVideos()
            _rawVideos.value = videos
            _state.value = State.Ready(videos)
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

    fun compress(video: VideoItem) {
        compress(listOf(video))
    }

    fun compress(videos: List<VideoItem>) {
        if (videos.isEmpty()) return
        CompressionService.enqueueCompressing(getApplication(), videos)
    }

    fun stopCompression() {
        CompressionService.stopCompressing(getApplication())
    }
}
