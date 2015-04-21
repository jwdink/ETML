# This takes a folder of session files, converts them to dataframe

## MAIN:
convert_session_files = function(path, 
                                 trial_advance_str= "TrialNum", 
                                 identifier_colnames = c("TrialNum", "BlockNum", "PhaseNum"),
                                 participant_string = "subject_code", 
                                 exp_time_string = "start_time",
                                 overwrite_conflict_function = NULL,
                                 echo=TRUE) {
  require("stringr")
  require("plyr") # for rbind.fill
  
  df = data.frame(stringsAsFactors= FALSE)
  
  files = list.files(path= path, pattern=".txt", all.files= TRUE, full.names= TRUE)
  for (file in files){
    if(echo) cat(sprintf("Processing file: %s\n", file))
    
    # read in the raw data file
    df_session = read.table(file, sep= "\t", header= FALSE, col.names = c('Key', 'Value'), stringsAsFactors= FALSE)
    df_session = df_session[2:nrow(df_session),]
    
    # Make Queue:
    this_row_is_new = FALSE
    this_row = NULL
    the_row_queue = data.frame(stringsAsFactors=FALSE)
    rq_identifiers = c()
    
    # Participant:
    part_str = df_session$Value[df_session$Key == participant_string]
    if (length(part_str) == 0) {
      warning("Could not find 'participant' in \n", file, "\n Check 'participant_string'.")
      part_str = 'NULL'
    }
    the_row_queue[1, fcoln(participant_string)] = part_str
    
    # Exp Time:
    time_str = df_session$Value[df_session$Key == exp_time_string]
    if (length(part_str) == 0) {
      warning("Could not find time in \n", file, "\n Check 'exp_time_string'.")
      time_str = 'NULL'
    }
    the_row_queue[1, fcoln(exp_time_string)] = time_str 
    
    
    # Loop thru:
    for (srow in 1:nrow(df_session)) { # srow = df_session row
      
      if ( df_session$Key[srow] == trial_advance_str ) {
        # we might be in a new trial.
        
        # we know that the prev row, which we were checking for uniqueness from the row queue, 
        # is unique iff the this_row_is_new==TRUE
        
        if (this_row_is_new) {
          # new? in that case, we can append the row queue to the df, flush it.
          df = rbind.fill(df, the_row_queue)
          the_row_queue = this_row
          rq_identifiers = as.list( the_row_queue[,identifier_colnames] )
          
          # reset:
          this_row = data.frame(stringsAsFactors=FALSE)
          this_row[1, fcoln(participant_string)] = part_str
          this_row[1, fcoln(exp_time_string)]    = time_str
          this_row_is_new = FALSE
        } else {
          # not new? merge into a single row_queue
          the_row_queue = merge_rows(the_row_queue, this_row)
          if (all( identifier_colnames %in% colnames(the_row_queue) )) {
            rq_identifiers = as.list( the_row_queue[,identifier_colnames] )
          }
          
          # reset:
          this_row = data.frame(stringsAsFactors=FALSE)
          this_row[1, fcoln(participant_string)] = part_str
          this_row[1, fcoln(exp_time_string)]    = time_str
          this_row_is_new = FALSE
        }

      }
      
      if (df_session$Key[srow] %in% names(rq_identifiers) ) {
        if (rq_identifiers[[ df_session$Key[srow] ]] != df_session$Value[srow]) { 
          # the value for this df_session row is a row-identifier value
          # does it equal the previous row-id val? if not, set the this_row_is_new_flag.
          this_row_is_new = TRUE
        }
      }
      
      if (!is.null(this_row)) { # ignores first few lines of session file with date etc.
        existing_val = this_row[1,fcoln(df_session$Key[srow])]
        
        if ( is.null(existing_val) ) {
          this_row[1,fcoln(df_session$Key[srow])] = df_session$Value[srow]
        } else {
          this_row[1,fcoln(df_session$Key[srow])] = merge_element(c(existing_val, df_session$Value[srow]),
                                                                  df_session$Key[srow],
                                                                  overwrite_conflict_function)
        } 
      }
      
    } # /loop thru rows
    # /loop thru files
  }
  
  return(df)
}

## HELPERS:
fcoln = function(coln) gsub(pattern = " ", replacement = "_", coln)

merge_rows = function(the_row_queue, this_row, overwrite_conflict_function) {
  if (is.null(this_row)) {
    return(the_row_queue)
  }
  
  two_rows = rbind.fill(the_row_queue, this_row)
  
  out = list()
  for (col in colnames(two_rows)) {
    out[[col]] = merge_element(two_rows[[col]], col, overwrite_conflict_function)
  }
  
  return( as.data.frame(out, stringsAsFactors=FALSE) )

}

merge_element = function(column, col, overwrite_conflict_function) {
  if (is.na(column[1])) return(column[2])
  if (is.na(column[2])) return(column[1])
  
  if (column[1] == column[2]) {
    return(column[1])
  }
  
  if (is.null(overwrite_conflict_function)) {
    warning(paste0("\nOverwrite in ouptut-column / session-key '", col, "'. Consider diff advance_str or specify overwrite_function.") )
    return( paste(temp_row[1,df_session_row$Key], df_session_row$Value, sep = "; ") )
  } else {
    return( overwrite_conflict_function(column[1], column[2], col) )
  }

}

