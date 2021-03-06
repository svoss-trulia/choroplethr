#' Create a choropleth from ACS data.
#' 
#' Creates a choropleth using the US Census' American Community Survey (ACS) data.  
#' Requires the acs package to be installed, and a Census API Key to be set with 
#' the acs's api.key.install function.
#'
#' @param tableId The id of an ACS table
#' @param lod A string indicating the level of detail of the map.  Must be "state", "county" or "zip".
#' @param num_buckets The number of equally sized buckets to places the values in.  A value of 1 
#' will use a continuous scale, and a value in [2, 9] will use that many buckets.  For
#' example, 2 will show values above or below the median, and 9 will show the maximum
#' resolution.  Defaults to 9.
#' @param showLabels For state choropleths, whether or not to show state abbreviations on the map.
#' Defaults to T. 
#' @return A choropleth
#' 
#' @keywords choropleth, acs
#' 
#' @seealso \code{\link{choroplethr}} which this function wraps
#' @seealso \code{\link{api.key.install}} which sets an Census API key for the acs library
#' @seealso http://factfinder2.census.gov/faces/help/jsf/pages/metadata.xhtml?lang=en&type=dataset&id=dataset.en.ACS_11_5YR#,
#' which contains a list of tables from the 2011 5 year ACS.
#' @importFrom acs acs.fetch geo.make
#' @export
choroplethr_acs = function(tableId, lod, num_buckets = 9, showLabels = T)
{
  stopifnot(lod %in% c("state", "county", "zip"))
  stopifnot(num_buckets > 0 && num_buckets < 10)
  
  acs.data   = acs.fetch(geography=make_geo(lod), table.number = tableId, col.names = "pretty")
  column_idx = get_column_idx(acs.data, tableId) # some tables have multiple columns 
  title      = acs.data@acs.colnames[column_idx] 
  acs.df     = make_df(lod, acs.data, column_idx) # choroplethr requires a df
  
  choroplethr(acs.df, lod, num_buckets, title, "", showLabels);
}

make_geo = function(lod)
{
  stopifnot(lod %in% c("state", "county", "zip"))
  if (lod == "state") {
    geo.make(state = "*")
  } else if (lod == "county") {
    geo.make(state = "*", county = "*")
  } else {
    geo.make(zip.code = "*")
  }
}

# support multiple column tables
get_column_idx = function(acs.data, tableId)
{
  column_idx = 1
  if (length(acs.data@acs.colnames) > 1)
  {
    num_cols   = length(acs.data@acs.colnames)
    title      = paste0("Table ", tableId, " has ", num_cols, " columns.  Please choose which column to render:")
    column_idx = menu(acs.data@acs.colnames, title=title)
  }
  column_idx
}

make_df = function(lod, acs.data, column_idx) 
{
  stopifnot(lod %in% c("state", "county", "zip"))
  
  if (lod == "state") {
    data.frame(region = geography(acs.data)$NAME, 
               value  = as.numeric(estimate(acs.data[,column_idx])));
  } else if (lod == "county") {
    # create fips code
    acs.data@geography$fips = paste(as.character(acs.data@geography$state), 
                                    acs.data@geography$county, 
                                    sep = "");
    # put in format for call to all_county_choropleth
    data.frame(region = geography(acs.data)$fips, 
               value  = as.numeric(estimate(acs.data)));
    
  } else if (lod == "zip") {
    # put in format for call to choroplethr
    acs.df = data.frame(region = geography(acs.data)$zipcodetabulationarea, 
                        value  = as.numeric(estimate(acs.data)))
    
    na.omit(acs.df) # surprisingly, this sometimes returns NA values
  }
}
