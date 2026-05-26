options(shiny.maxRequestSize = 500 * 1024^2)

library(shiny)
library(bslib)
library(plotly)
library(DT)
library(tuneR)
library(seewave)
library(data.table)
library(shinycssloaders)
library(tools)
library(DiagrammeR) 
library(visNetwork)


# UI Definition (Cloud Search Theme)

custom_theme <- bs_theme(
  bg = "#0A0A0A", fg = "#FFFFFF", primary = "#FF8C00",
  base_font = font_google("Inter"),
  heading_font = font_google("Montserrat")
)

ui <- page_navbar(
  theme = custom_theme,
  
  tags$head(
    tags$style(HTML("
      @keyframes pulse-orange {
        0% { transform: scale(0.98); box-shadow: 0 0 0 0 rgba(255, 140, 0, 0.6); }
        70% { transform: scale(1); box-shadow: 0 0 0 25px rgba(255, 140, 0, 0); }
        100% { transform: scale(0.98); box-shadow: 0 0 0 0 rgba(255, 140, 0, 0); }
      }
      .circle-match {
        width: 300px; height: 300px; border-radius: 50%;
        background: linear-gradient(135deg, #FF8C00, #E65C00);
        display: flex; flex-direction: column; align-items: center; justify-content: center;
        animation: pulse-orange 2s infinite; margin: 0 auto;
        box-shadow: 0 10px 30px rgba(255,140,0,0.4);
      }
      .circle-waiting {
        width: 250px; height: 250px; border-radius: 50%;
        border: 4px dashed #333333; display: flex; align-items: center; justify-content: center;
        margin: 0 auto; transition: all 0.5s ease;
      }
    "))
  ),
  
  title = tags$div(icon("cloud", style = "color: #FF8C00; margin-right: 8px;"), "Cloud Search"),
  
  # TAB 1: Live Engine
  nav_panel("Live Engine",
            layout_sidebar(
              sidebar = sidebar(
                width = 350, bg = "#1A1A1A",
                h4("Live Listening"),
                fileInput("snippet_upload", "Upload Audio Snippet (.wav)", accept = c(".wav")),
                hr(),
                tags$p("Upload a snippet to trigger the matching algorithm.", style = "color: #888888; font-size: 0.9em;")
              ),
              
              layout_columns(
                col_widths = c(12, 12, 12),
                
                card(
                  bg = "#0A0A0A", style = "border: none; padding-top: 40px;",
                  uiOutput("match_circle_ui") %>% withSpinner(color = "#FF8C00", type = 8)
                ),
                
                # NEW: Voice-Memo Style Waveform Chart
                card(
                  bg = "#0A0A0A", style = "border: none;",
                  plotlyOutput("wave_plot", height = "120px") %>% withSpinner(color = "#FF8C00")
                ),
                
                # 3D Surface for the Snippet
                card(
                  card_header("3D Spectral Surface (Live Snippet)"),
                  plotlyOutput("surface_3d_plot", height = "400px")
                )
              )
            )
  ),
  
  # TAB 2: Topological Engine (Visualizations)
  nav_panel("Topological Engine",
            layout_columns(
              col_widths = c(12, 12),
              
              card(
                card_header("System Architecture & Data Flow"),
                visNetworkOutput("flowchart", height = "300px")
              ),
              
              card(
                card_header(
                  class = "d-flex justify-content-between align-items-center",
                  "Topological Constellation Maps",
                  selectInput("viz_track_selector", NULL, choices = c("Live Snippet (Upload First)"), width = "300px")
                ),
                plotlyOutput("constellation_plot", height = "500px") %>% withSpinner(color = "#FF8C00"),
                tags$p("This isolates the 'DNA' Landmarks of the specific track you selected above.", style = "color: #A9A9A9; font-size: 0.9em;")
              )
            )
  ),
  
  # TAB 3: Database Ingestion
  nav_panel("Database Ingestion",
            layout_columns(
              col_widths = c(5, 7),
              card(
                card_header("Batch Ingest Tracks"),
                fileInput("db_upload", "Upload Full Audio Tracks (.wav)", accept = c(".wav"), multiple = TRUE),
                actionButton("add_to_db_btn", "Process Batch to Database", class = "btn-warning"),
                hr(),
                h5(textOutput("db_status_text"), style = "color: #FF8C00;")
              ),
              card(
                card_header("Track Library (Available Songs)"),
                DTOutput("database_table") %>% withSpinner(color = "#FF8C00")
              )
            )
  )
)


# Server Logic 

server <- function(input, output, session) {
  
  # --- STATE MANAGEMENT ---
  snippet_data <- reactiveVal(NULL)
  app_database <- reactiveVal(data.table(Hash = character(), Song_ID = character(), Absolute_Time_of_Anchor = numeric()))
  
  db_peaks_storage <- reactiveVal(list()) 
  
  observeEvent(input$add_to_db_btn, {
    req(input$db_upload)
    
    withProgress(message = 'Ingesting Audio Library...', value = 0, {
      n_files <- nrow(input$db_upload)
      current_peaks_list <- db_peaks_storage()
      
      new_hashes_list <- lapply(1:n_files, function(i) {
        file_name <- file_path_sans_ext(input$db_upload$name[i])
        incProgress(1/n_files, detail = paste("Extracting:", file_name))
        
        file_path <- input$db_upload$datapath[i]
        new_spec <- generate_spectrogram(file_path)
        new_peaks <- extract_peaks(new_spec)
        
        # Save peaks strictly for the Constellation Map UI
        current_peaks_list[[file_name]] <<- new_peaks
        
        return(generate_hashes(new_peaks, file_name))
      })
      
      db_peaks_storage(current_peaks_list) # Update peak storage
      
      new_hashes <- rbindlist(new_hashes_list)
      current_db <- app_database()
      updated_db <- unique(rbind(current_db, new_hashes))
      app_database(updated_db)
      
      updateSelectInput(session, "viz_track_selector", 
                        choices = c("Live Snippet", names(current_peaks_list)))
    })
    
    output$db_status_text <- renderText({ paste("Successfully processed", nrow(input$db_upload), "tracks into the library!") })
  })
  
  output$database_table <- renderDT({
    db <- app_database()
    if(nrow(db) == 0) return(datatable(data.frame(Message = "Database is empty."), options = list(dom = 't')))
    
    summary_db <- db[, .(Landmarks_Stored = .N), by = .(Track_Name = Song_ID)]
    datatable(summary_db, options = list(pageLength = 10, dom = 't', scrollX = TRUE),
              rownames = FALSE, class = 'cell-border stripe dt-dark') %>%
      formatStyle(columns = colnames(summary_db), color = 'white', backgroundColor = '#1A1A1A')
  })
  
  # --- TAB 1: RECOGNITION LOGIC ---
  observeEvent(input$snippet_upload, {
    req(input$snippet_upload)
    db <- app_database()
    
    if (nrow(db) == 0) {
      showNotification("Your database is empty! Add songs in the 'Database Ingestion' tab first.", type = "error")
      return()
    }
    
    withProgress(message = 'Analyzing Topologies...', detail = "Searching Database", value = 0.5, {
      winner <- recognize_snippet(input$snippet_upload$datapath, db)
      
      if (!is.character(winner) && winner$Coherence_Score < 15) {
        winner <- "No matches found." 
      }
      
      spec <- generate_spectrogram(input$snippet_upload$datapath)
      peaks <- extract_peaks(spec)
      
      raw_wave <- readWave(input$snippet_upload$datapath)
      if (raw_wave@stereo) raw_wave <- mono(raw_wave, "both")
      
      snippet_data(list(winner = winner, spec = spec, peaks = peaks, wave = raw_wave))
    })
  })
  
  output$match_circle_ui <- renderUI({
    data <- snippet_data()
    if (is.null(data)) return(tags$div(class = "circle-waiting", tags$h4("Awaiting Audio...", style = "color: #555555;")))
    if (is.character(data$winner)) return(tags$div(class = "circle-waiting", style = "border-color: #FF3333;", tags$h4("No Match Found", style = "color: #FF3333;")))
    
    tags$div(class = "circle-match",
             tags$h3(data$winner$Song_ID_db, style = "color: white; font-weight: bold; text-align: center; padding: 0 15px; margin-bottom: 10px;"),
             tags$h6(paste("Offset:", data$winner$Time_Offset, "sec"), style = "color: rgba(255,255,255,0.8); margin: 0;"),
             tags$h6(paste("Score:", data$winner$Coherence_Score), style = "color: rgba(255,255,255,0.8); margin: 0;")
    )
  })
  
  output$wave_plot <- renderPlotly({
    req(snippet_data())
    wave <- snippet_data()$wave
    
    down_n <- min(length(wave@left), 3000)
    idx <- round(seq(1, length(wave@left), length.out = down_n))
    time_seq <- seq(0, length(wave@left)/wave@samp.rate, length.out = down_n)
    amp <- wave@left[idx]
    
    plot_ly(x = ~time_seq, y = ~amp, type = 'scatter', mode = 'lines',
            line = list(color = '#FF8C00', width = 2), fill = 'tozeroy', fillcolor = 'rgba(255,140,0,0.15)') %>%
      layout(plot_bgcolor = 'transparent', paper_bgcolor = 'transparent',
             xaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE),
             yaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE),
             margin = list(l=0, r=0, t=0, b=0)) %>%
      config(displayModeBar = FALSE)
  })
  
  output$surface_3d_plot <- renderPlotly({
    req(snippet_data())
    spec <- snippet_data()$spec
    z_matrix <- spec$amp
    if(ncol(z_matrix) > 200) z_matrix <- z_matrix[, seq(1, ncol(z_matrix), length.out = 200)]
    if(nrow(z_matrix) > 200) z_matrix <- z_matrix[seq(1, nrow(z_matrix), length.out = 200), ]
    plot_ly(z = ~z_matrix, type = "surface", colorscale = "YlOrRd") %>%
      layout(scene = list(
        xaxis = list(title = "Time", gridcolor = '#333333', color = '#FFFFFF'),
        yaxis = list(title = "Frequency", gridcolor = '#333333', color = '#FFFFFF'),
        zaxis = list(title = "Amplitude", gridcolor = '#333333', color = '#FFFFFF')
      ), paper_bgcolor = '#0A0A0A', font = list(color = '#FFFFFF'))
  })
  
  output$flowchart <- renderVisNetwork({
    nodes <- data.frame(
      id = 1:11,
      label = c("Raw Audio .wav", "Downsample & Mono", "Fast Fourier Transform",
                "Spectrogram Matrix", "Peak Extraction", "Constellation Map",
                "Combinatorial Hashes", "Fingerprint Database",
                "Live Snippet", "Match Engine", "Match Output"),
      shape = c("box", "ellipse", "diamond", "box", "ellipse", "box", "ellipse", "database", "box", "diamond", "box"),
      color = c("#1A1A1A", "#1A1A1A", "#1A1A1A", "#1A1A1A", "#1A1A1A", "#1A1A1A", "#1A1A1A", "#222222", "#1A1A1A", "#1A1A1A", "#FF8C00"),
      font.color = c("white", "white", "white", "white", "white", "white", "white", "white", "white", "white", "black"),
      level = c(1, 2, 3, 4, 5, 6, 7, 8, 7, 8, 9) # This forces the top-to-bottom layout
    )
    
    edges <- data.frame(
      from = c(1, 2, 3, 4, 5, 6, 7, 9, 8, 10),
      to =   c(2, 3, 4, 5, 6, 7, 8, 10, 10, 11),
      color = "#888888"
    )
    
    visNetwork(nodes, edges) %>%
      visHierarchicalLayout(direction = "LR", sortMethod = "directed") %>%
      visEdges(arrows = "to") %>%
      visOptions(highlightNearest = TRUE) %>%
      visInteraction(dragNodes = FALSE, dragView = TRUE, zoomView = TRUE)
  })
  output$constellation_plot <- renderPlotly({
    selected <- input$viz_track_selector
    
    if (selected == "Live Snippet" || selected == "Live Snippet (Upload First)") {
      req(snippet_data())
      peaks <- snippet_data()$peaks
    } else {
      # Pull the specific song's peaks from our new storage list
      peaks <- db_peaks_storage()[[selected]]
      req(peaks)
    }
    
    plot_ly(data = peaks, x = ~Time, y = ~Freq, type = 'scatter', mode = 'markers',
            marker = list(size = 4, color = '#FF8C00', opacity = 0.8),
            hoverinfo = 'text', text = ~paste("Time:", round(Time, 2), "s<br>Freq:", round(Freq, 2), "kHz")) %>%
      layout(plot_bgcolor = '#1A1A1A', paper_bgcolor = '#0A0A0A',
             xaxis = list(title = "Time (s)", gridcolor = '#333333', color = '#FFFFFF'),
             yaxis = list(title = "Frequency (kHz)", gridcolor = '#333333', color = '#FFFFFF'), font = list(color = '#FFFFFF'))
  })
}

shinyApp(ui, server)
