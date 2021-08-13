#DATA FRA IMDIS API

#libraries
library(httr)
library(jsonlite)
library(dplyr)

#krever at data er på korrekt spørreformat

#funksjon
imdi_fetch = function(data){
  temp_queryresult = POST("https://imdifakta.azurewebsites.net/api/v1/data/query",body=data,encode="json",verbose(),content_type_json())
  temp_df = fromJSON(content(temp_queryresult,"text",encoding="UTF-8"))
  if(length(temp_df)==1){
    return(temp_df[[1]])
  }
  if(length(temp_df)>1){
    temp_df_final = data.frame()
    temp_df_final = bind_rows(temp_df_final,temp_df[[2]])
    i = 0
  }
  #bruker en while-loop, og det er vel fy?
  while(length(temp_df)>1){
    i = i+1
    temp_token = temp_df$continuation
    temp_token_format = paste0('{','"continuation":"',temp_token,'",')
    new_data = substring(data,2,nchar(data)+1)
    new_data_query =paste0(temp_token_format,new_data)
    temp_queryresult = POST("https://imdifakta.azurewebsites.net/api/v1/data/query",body=new_data_query,encode="json",verbose(),content_type_json())
    temp_df = fromJSON(content(temp_queryresult,"text",encoding="UTF-8"))
    if(length(temp_df)>1){
      temp_df_final = bind_rows(temp_df_final,temp_df[[2]])
      Sys.sleep(5) #høfflig å ikke spørre for mange ganger
    }
    if(length(temp_df)==1){
      temp_df_final = bind_rows(temp_df_final,temp_df[[1]])
      print(paste0("Fullført på ",i," repetisjoner"))
    }
  }
  return(temp_df_final)
}

imdi_fetch_compare = function(data){
  temp_queryresult = POST("https://imdifakta.azurewebsites.net/api/v1/data/compare",body=data,encode="json",verbose(),content_type_json())
  temp_df = fromJSON(content(temp_queryresult,"text",encoding="UTF-8"))
  if(length(temp_df)==1){
    return(temp_df[[1]])
  }
  if(length(temp_df)>1){
    temp_df_final = data.frame()
    temp_df_final = bind_rows(temp_df_final,temp_df[[2]])
    i = 0
  }
  #bruker en while-loop, og det er vel fy?
  while(length(temp_df)>1){
    i = i+1
    temp_token = temp_df$continuation
    temp_token_format = paste0('{','"continuation":"',temp_token,'",')
    new_data = substring(data,2,nchar(data)+1)
    new_data_query =paste0(temp_token_format,new_data)
    temp_queryresult = POST("https://imdifakta.azurewebsites.net/api/v1/data/compare",body=new_data_query,encode="json",verbose(),content_type_json())
    temp_df = fromJSON(content(temp_queryresult,"text",encoding="UTF-8"))
    if(length(temp_df)>1){
      temp_df_final = bind_rows(temp_df_final,temp_df[[2]])
      Sys.sleep(5) #høfflig å ikke spørre for mange ganger
    }
    if(length(temp_df)==1){
      temp_df_final = bind_rows(temp_df_final,temp_df[[1]])
      print(paste0("Fullført på ",i," repetisjoner"))
    }
  }
  return(temp_df_final)
}

#hva skal til for å få ut alle data?
#for transformering til kommaseparert streng
#tar en vektor som input og returnerer den som streng
vektor_til_streng = function(temp_navn){
  for(i in 1:length(temp_navn)){
    if(i==1){
      temp_string = paste0('"',temp_navn[i],'"')
    }
    if(i>1){
      temp_string = paste0(temp_string,',"',temp_navn[i],'"') 
    }
  }
  return(temp_string)
}

finn_tabeller = function(){
  url = "https://imdifakta.azurewebsites.net/api/v1/metadata/tables"
  temp_df = data.frame(datasett = fromJSON(content(GET(url),"text",encoding="UTF-8")),stringsAsFactors = FALSE)
  return(temp_df)
}

finn_headergruppe = function(tabell_navn="befolkning_hovedgruppe",level="kommuneNr"){
  url = paste0('https://imdifakta.azurewebsites.net/api/v1/metadata/headergroups/',tabell_navn)
  temp_df = fromJSON(content(GET(url),"text",encoding="UTF-8")) #gir meg en df med lister
  temp_navn = names(temp_df)
  #antar at det eneste som varierer mellom headergruppene er xNr
  #fjerner alle andre geo-levels fra headergruppa
  geo_levels = c("bydelNr","kommuneNr","naringsregionNr","fylkeNr")
  geo_levels = geo_levels[grep(level,geo_levels,fixed=TRUE,invert=TRUE)]
  for(i in 1:length(geo_levels)){
    temp_navn = temp_navn[grep(geo_levels[i],temp_navn,fixed=TRUE,invert=TRUE)]
  }
  temp_headergruppe = vektor_til_streng(temp_navn)
  return(temp_headergruppe)
}

finn_variabelverdier = function(variabel = "enhet",tabell_navn="befolkning_hovedgruppe"){
  url = paste0('https://imdifakta.azurewebsites.net/api/v1/metadata/headergroups/',tabell_navn)
  temp_df = fromJSON(content(GET(url),"text",encoding="UTF-8"))
  #finner posisjonen til variabelen, i standard-tilfellet enhet, og returnerer unike verdier på den variabelen over alle header_grupper
  #bygger på en antakelse om at enheter ikke varier på tvers av tabeller...den holder sikkert ikke?
  enheter = unique(unlist(temp_df[grep(variabel,names(temp_df),fixed=TRUE)]))
  enheter = vektor_til_streng(enheter)
  return(enheter)
}

#bygg en spørring for alle 

#her mangler det bl.a. en "finn variabler" hvis denne skal generaliseres til noe som gir mer kontroll
#men det burde ikke være alt for vanskelig
#det vanskelige er p.t. å finne hvilke variabler og verdier som er gyldig for et spesifikt headergruppe/geonivå

bygg_query = function(tabell_navn="befolkning_hovedgruppe",level="kommuneNr",variabel="enhet"){
  temp_data = 
    paste0(
      '{"TableName":"',tabell_navn,'",
  "Include":
    [',finn_headergruppe(tabell_navn=tabell_navn,level=level),'],
    "Conditions":
      {"enhet":[',finn_variabelverdier(variabel=variabel,tabell_navn=tabell_navn),']}
}'
    )  
  return(temp_data)
}

#med disse byggeklossene kan jeg lage en funksjon som returnerer en hel tabell for et nivå, uten kunnskap om innholdet
imdi_fetch_table = function(tabell_navn="bosatt_anmodede",level="kommuneNr"){
  temp_data = bygg_query(tabell_navn=tabell_navn,level=level,variabel="enhet")
  temp_df = imdi_fetch(temp_data)
}

