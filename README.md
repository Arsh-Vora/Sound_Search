
# Sound Search ☁️🔍
---

## 📌 Project Overview

**Sound Search** is a high-speed, professional-grade audio recognition platform built completely from scratch within the R programming language. Rather than relying entirely on black-box algorithmic matching heuristics, this framework models acoustic signals mathematically. It bridges **Functional Data Analysis (FDA)** and **Topological Data Analysis (TDA)** to convert, index, and match complex audio signatures in real time.

### 🌟 Key Highlights
* **Mathematical Precision:** Formally handles continuous sound domains rather than treating audio as isolated, disconnected discrete rows.
* **Optimized for Complexity:** Built-in custom localized grid pruning designed specifically to bypass database bloating when handling modern compressed loops.
* **Production Deployment:** Packaged into an interactive **R Shiny** dark-themed user interface featuring 3D spectral terrain renderings and dynamic data flow maps.

---

## ⚙️ Core Technical Workflow

The architecture processes and aligns incoming sound signals sequentially across four highly optimized development phases:


```

┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ Raw Audio (.wav)│ ───> │  Normalization  │ ───> │ Fourier (STFT)  │
└─────────────────┘      └─────────────────┘      └─────────────────┘
│
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐  │
│ Verified Match  │ <─── │Shift-Registration│ <─── │ Grid-Pruning Max│ <─┘
└─────────────────┘      └─────────────────┘      └─────────────────┘

```

| Phase | Engine Layer | Technical Implementation Details |
| :--- | :--- | :--- |
| **1** | **Acoustic Standardization** | • Collapses multi-channel spatial fields into a single monaural array to eliminate phase variance.<br>• Uniformly downsamples tracks to `22050 Hz` to drop ultrasonic overhead while preserving core harmonic information. |
| **2** | **Functional Transformation** | • Slices vectors into localized blocks using a 1024-sample sliding window with a 50% overlap rule.<br>• Multiplies frames by a tapered **Hamming Window Kernel** to suppress boundary discontinuities (spectral leakage).<br>• Projects results onto continuous sine and cosine pathways via the Fast Fourier Transform (FFT). |
| **3** | **Topological Pruning** | • Segregates frequency spectrums into 6 distinct logarithmic bands mimicking human auditory sensitivity.<br>• Implements a **Spatio-Temporal Grid Constraint** (0.5-second blocks) to enforce exactly *one* dominant local maximum peak per space cell, thinning data footprint by 95%. |
| **4** | **Combinatorial Matching** | • Pairs structural anchor peaks with 5 subsequent target peaks within a constrained forward time zone.<br>• Serializes combinations into highly explicit alphanumeric unique keys stored within a vectorized `data.table`. |

---

## 🛠️ Precision Cross-Alignment & Anti-False Positive Engine

The search system bypasses slow, iterative loops by executing a vectorized inner join directly on the unique keys. 

### ⏱️ Non-Parametric Shift Registration
If an input snippet belongs to a reference database track, the difference between the absolute reference timestamp ($t_{db}$) and the relative snippet timestamp ($t_{snip}$) must match across all valid keys by a constant time translation parameter ($\delta$):

$$\delta = t_{db} - t_{snip}$$

The match winner is decided by finding the absolute highest global peak inside a time-offset synchronization histogram (the **Coherence Score**).

### 🛡️ The Confidence Barrier
To protect your engine from false matches when an unindexed track is cross-referenced against your library, a conditional statistical floor is explicitly programmed into the server:

* **Coherence Score $\ge 15$:** Match Verified.
* **Coherence Score $< 15$:** Low-level noise alignment. Reverted to a clean `"No Match Found"` state.

---

## 📊 Advanced Statistical Extension: Functional ANOVA

Beyond point-to-point lookup, this repository includes an advanced module executing **Functional Analysis of Variance (FANOVA)** to compare the macro-structural energy shapes of audio profiles:
* **Non-Periodic Basis Projection:** Maps global track spectrums onto a continuous, cubic **B-Spline Basis System** ($m=4$).
* **Regularization:** Utilizes an integrated roughness penalty lambda ($\lambda$) over the second derivative to ensure smooth, interpretable structural shapes.
* **Functional F-Ratio Test:** Computes a continuous $F(f)$ curve across the frequency scale, identifying exactly which precise bandwidths contain statistically significant variations across different musical genres.

---

## 📁 Repository Structure

```text
├── Main.R                  # Backend Mathematical Signal Processing Stack (Phases 1-5)
├── Trial.R                 # Core Production R Shiny Application UI & Server Logic (Cloud Search)
├── FNTA_Project.Rproj      # R Project configuration infrastructure file
├── .gitignore              # Version-control exclusions (ignores local data/ & cache files)
└── README.md               # Comprehensive system architectural documentation

```

---

## 🚀 Getting Started

### 1. Install Software Dependencies

Open your R console and run the following command to update your environment libraries:

```R
install.packages(c("shiny", "bslib", "plotly", "DT", "tuneR", "seewave", "data.table", "shinycssloaders", "visNetwork"))

```

### 2. Launch the Application

1. Open the project repository inside **RStudio**.
2. Open `Main.R`, select all lines, and press **Run** to load the signal processing mathematical pipeline into local memory.
3. Open `Trial.R` and click the **Run App** button located in the top-right corner of the script editor panel.
4. Navigate to the **Database Ingestion** tab to batch-upload your reference tracks, then switch back to the **Live Engine** tab to test your recognition matrix!

```

```
