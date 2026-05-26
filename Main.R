library(tuneR) 
library(seewave)    
library(fftwtools) 
library(data.table) 
library(fda)        
library(TDA)       


# Pre-processing & Spectrogram
generate_spectrogram <- function(file_path) {
  song <- readWave(file_path)
  
  if (song@stereo) {
    song <- mono(song, which = "both")
  }
  
  song_ds <- resamp(song, f = song@samp.rate, g=22050, output = "Wave")
  
  # Applying a 1024 sliding window with a 50% overlap and a Hamming window to prevent spectral leakage
  # Frequency Filtering: flim limits the range to 0.02 - 5 kHz (20 Hz - 5 kHz)
  spec <- spectro(song_ds, wl = 1024, ovlp = 50, plot = FALSE, flim = c(0.02, 5))
  
  return(spec)
}




# Peak Extraction (Topological Landmarks)

extract_peaks <- function(spec) {
  time_seq <- spec$time
  freq_seq <- spec$freq
  amp_mat <- spec$amp
  
  dt <- as.data.table(expand.grid(Freq = freq_seq, Time = time_seq))
  dt$Amp <- as.vector(amp_mat)
  
  bands <- c(0, 0.5, 1, 1.5, 2.5, 3.5, 5)
  dt[, Band := cut(Freq, breaks = bands, include.lowest = TRUE)]
  
  # 1. GLOBAL FILTER: Only consider the top 5% loudest frequencies in the ENTIRE song
  global_thresh <- quantile(dt$Amp, 0.95, na.rm = TRUE)
  dt_filtered <- dt[Amp > global_thresh]
  
  # 2. Extract the max peak per band in the surviving time segments
  peaks <- dt_filtered[dt_filtered[, .I[which.max(Amp)], by = .(Time, Band)]$V1]
  
  # 3. THE CULL: Keep only the top 15% loudest of these extracted peaks to guarantee a sparse map
  final_thresh <- quantile(peaks$Amp, 0.85, na.rm = TRUE)
  peaks <- peaks[Amp > final_thresh]
  
  return(peaks[, .(Time, Freq, Amp)])
}
# Combinatorial Hashing

generate_hashes <- function(peaks, song_id) {
  # Sort by time to ensure we look "ahead"
  setorder(peaks, Time)
  
  hash_list <- lapply(1:5, function(step) {
    peaks[, .(
      Song_ID = song_id,
      Anchor_Freq = Freq,
      Target_Freq = shift(Freq, n = step, type = "lead"),
      Absolute_Time_of_Anchor = Time,
      Delta_T = shift(Time, n = step, type = "lead") - Time
    )]
  })
  
  hashes <- rbindlist(hash_list)
  hashes <- na.omit(hashes) # Remove NA values generated at the end of the timeline
  
  hashes[, Hash := paste(round(Anchor_Freq, 3), round(Target_Freq, 3), round(Delta_T, 3), sep = "|")]
  
  # Return table: [Hash | Song_ID | Absolute_Time_of_Anchor]
  return(hashes[, .(Hash, Song_ID, Absolute_Time_of_Anchor)])
}

# The Recognition Engine (With Thresholding)
recognize_snippet <- function(snippet_file, database) {
  # 1. Process the snippet
  spec_snip <- generate_spectrogram(snippet_file)
  peaks_snip <- extract_peaks(spec_snip)
  hashes_snip <- generate_hashes(peaks_snip, "Snippet")
  
  # 2. Force deduplication
  hashes_snip <- unique(hashes_snip)
  database <- unique(database)
  
  # 3. Inner join to find matches
  matches <- merge(hashes_snip, database, by = "Hash", 
                   suffixes = c("_snip", "_db"), 
                   allow.cartesian = TRUE)
  
  # If literally zero hashes matched, reject
  if (nrow(matches) == 0) return("No matches found.")
  
  # 4. Time Coherence calculation
  matches[, Time_Offset := round(Absolute_Time_of_Anchor_db - Absolute_Time_of_Anchor_snip, 2)]
  
  # 5. Score tallying
  coherence <- matches[, .(Coherence_Score = .N), by = .(Song_ID_db, Time_Offset)]
  
  # Find the highest scoring match
  winner <- coherence[which.max(Coherence_Score)]
  
  # THE FIX: The Confidence Threshold
  # If the "winning" score is just random low-level noise (e.g., less than 15 matches),
  # we mathematically reject it as a false positive.
  if (winner$Coherence_Score < 15) {
    return("No matches found.")
  }
  
  return(winner)
}

# Execution Example
#Build your Database
#my_spec <- generate_spectrogram("data/JVKE - her (official lyric video) - JVKE (128k).wav")
#my_peaks <- extract_peaks(my_spec)
#my_db <- generate_hashes(my_peaks, "Song_A")
# Keep only unique rows, effectively deleting the accidental double-entry
#my_db <- unique(my_db)

#Test a Snippet
#result <- recognize_snippet("data/JVKE - her Ringtone.wav", my_db)
#print(result)
