# This takes a folder of session files made by ETML, and converts them into an R dataframe

convert_session_files = function(path, trial_advance_str= "trial", echo=FALSE) {
  require("stringr")
  
  df = data.frame('Participant' = character(0), 
                  'Date'        = as.POSIXct(character(0)),
                  'Comments'    = character(0),
                  'Phase'       = numeric(0),
                  'Block'       = numeric(0),
                  stringsAsFactors= FALSE)
  
  files = list.files(path= path, pattern=".txt", all.files= TRUE, full.names= TRUE)
  trow = 0
  for (file in files){
    if(echo) cat(sprintf("Processing file: %s\n", file))
    
    # read in the raw data file
    df_session = read.table(file, sep= "\t", header= TRUE, col.names = c('Key', 'Value'), stringsAsFactors= FALSE)
    
    # Loop thru:
    trial = 0
    for (srow in 1:nrow(df_session)) { # srow = df_session row
      
      # Advance trial?:
      if ( df_session$Key[srow] == trial_advance_str ) {
        trial = trial + 1
        trow = trow + 1  # trow = target data row
        df[trow,] = rep(NA, times = ncol(df)) # add an empty row
        df[trow,"Participant"] = df_session$Value[df_session$Key == "Subject Code"]
        df[trow,"Date"]        = df_session$Value[df_session$Key == "Start Time"]
        df[trow,"Comments"]    = paste0(df_session$Value[df_session$Key == "Comments"],"")
      }
      
      if (trial > 0) {
        if (! df_session$Key[srow] %in% colnames(df)) {
          df[,df_session$Key[srow]] = NA
        }
        df[trow, df_session$Key[srow]] = df_session$Value[srow]
      }
      
    } # /loop thru rows
    # /loop thru files
  }
  
  return(df)
}