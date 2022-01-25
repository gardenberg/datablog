---
title: Hvordan hente data fra Doffin?
author: Eivind
date: '2022-01-25'
slug: []
categories: []
tags: []
meta_img: images/image.png
description: Description for the page
---

__Hva handler denne artikkelen om?__ _Målet er å lage en webscraper som regelmessig henter data fra Doffin om relevante utlysninger. Det ser ut til å funke fint - dermed kan en med litt mer jobb, evt. jevnlig kjøring, lage seg et system som automatisk finner nye aktuelle utlysninger når de lyses ut. En kan også hente data til analyser av utlysningsmarkedet._

[Doffin](https://www.doffin.no/) er den nasjonale kunngjøringsdatabasen for offentlige anskaffelser på doffin.no . 

- For å holde seg oppdatert på aktuelle kunngjøringer, kan det være en fordel å med jevne mellomrom få varslinger om nye kunngjøringer. 
- Det kan også være nyttig å kunne sette opp abonnementer på relativt komplekse søk (f.eks. etter flere oppdragsgivere en kjenner godt, mange mindre oppdragsgivere som publiserer sjeldnere og dermed lettere går under radaren). 
- Det kan også potensielt være verdi å kunne se statistikk over omfanget av utlysninger etter ulike parametre (som. f.eks. om det er spesielle måneder hvor det lyses ut spesielt mye FoU-prosjekter, om det er aktører som i større eller mindre grad bruker Doffin (og dermed heller bruker andre anskaffelseskanaler).

Men Doffin-nettsida tilbyr i dag lite som passer slikt. Doffin er kun en database og et web-grensesnitt for å søke i databasen, og tilbyr ikke selv noen tjenester som dekker dette. 

Jeg har tidligere (i en anna sammenheng) vært i kontakt med daværende eier av Doffin-databasen, og undersøkte mulighetene for å få den utlevert. Det førte ingen steder. Vi må dermed ta sakene i egne hender. Det ser heller ikke ut til å ligge noe kode åpent tilgjengelig som gjør det samme, men et par ting finnes dog: 
- En [open source-entusiast](https://github.com/petterreinholdtsen/local-doffin-db) har laget en webscraper for scraperwiki for å konvertere Doffin til en lokal sqlite-database. Den er sist oppdatert i 2006, og jeg snakker ikke scraperwiki (eller QuickCode, som det heter nå? En plattform for R og Python? Verdt å kikke nærmere på ved en anna anledning.)
- Det finnes også, i [gist-form på GitHub](https://gist.github.com/ringe/db4c2fde97b9b8ae5fee), en Ruby-basert "Mechanize based Sidekiq Worker" som rapporterer om nye utlysninger. Den ble sist oppdatert for 7 år siden, og jeg snakker ikke Ruby heller.

# Hvordan løse dette

Begge kode-eksemplene jeg fant bruker webscraping med xpath og css-selectorer. En kikk på nettsida med konsollet i Chrome, bekrefter på at dataene ikke hentes fra noe åpent tilgjengelig API eller lignende. 

For å hente ut informasjonen må en dermed lese inn HTML-filene, og behandle disse. Dermed trenger vi disse bibliotekene:


```r
#biblioteker
library(tidyverse)
library(rvest) #scrape-pakke
library(janitor) #for den hendige get_dupes()-funksjonen
library(robotstxt) #for å spørre om jeg får lov til å skrape
```

Planen er å bruke  rvest til å simulere ulike former for søk mot Doffin, og så hente ut informasjonen i tabellform på en slik måte at det kan sorteres og visualiseres. Evt. også formatere det om til lesbar tekst igjen. 

## Obsobs - er det lov?

Før en stuper inn i det, er det et par ting som må avklares:

- Tillater [brukerbetingelsene for Doffin](https://doffin.no/Home/TermOfUseSupplier) at vi bruker innholdet? 

I følge betingelsene (i skrivende stund, januar 2022) tilhører alt materiale enten EU-supply eller Nærings- og fiskeridepartementet, men rettighetene er også overført Fornyings- og administrasjonsdepartementet - med mindre annet er oppgitt. 

Det er ikke spesielt tydelig, ettersom FAD ble lagt ned i 2014, og EU-supply ikke lenger er leverandør for Doffin. Det står imidlertid ingenting om bruk av materialet i betingelsene. Ettersom dette er en offentlig portal for publisering av informasjon, legger jeg derfor til grunn at materialet kan hentes ned. Hvis en skulle brukt det i et prosjekt eller til å lage et produkt, ville jeg imidlertid tatt kontakt med noen for å oppklare dette.

- Tillater nettsida at vi bruker en robot for å skrape ut innholdet? 

En av flere guider er [her](https://stevenmortimer.com/scraping-responsibly-with-r/), som anbefaler [robotstxt-pakka](https://cran.r-project.org/web/packages/robotstxt/vignettes/using_robotstxt.html). Her kan en teste enkelt-stier i robots.txt-fila på nettsida, og se om det er tillatt for roboter å aksessere den. Jeg sjekker for et generelt søkeresultat og en enkelt kunngjøring:


```r
#for søkeresultatet
paths_allowed(
  paths = "/Notice/?query=&PageNumber=1&PageSize=10&OrderingType=0&OrderingDirection=1&RegionId=&CountyId=&MunicipalityId=&IsAdvancedSearch=false&location=&NoticeType=&PublicationType=&IncludeExpired=false&Cpvs=&EpsReferenceNr=&DeadlineFromDate=&DeadlineToDate=&PublishedFromDate=&PublishedToDate=",
  domain = "doffin.no",
  bot = "*"
)
```

```
## doffin.no
```

```
## Warning in request_handler_handler(request = request, handler = on_not_found, :
## Event: on_not_found
```

```
## Warning in request_handler_handler(request = request, handler =
## on_file_type_mismatch, : Event: on_file_type_mismatch
```

```
## Warning in request_handler_handler(request = request, handler =
## on_suspect_content, : Event: on_suspect_content
```

```
## 
```

```
## [1] TRUE
```

```r
#for ett enkelt-oppslag/en enkelt kunngjøring
paths_allowed(
  paths = "Notice/Details/2022-360774",
  domain = "doffin.no",
  bot = "*"
)
```

```
## doffin.no
```

```
## Warning in request_handler_handler(request = request, handler = on_not_found, :
## Event: on_not_found
```

```
## Warning in request_handler_handler(request = request, handler =
## on_file_type_mismatch, : Event: on_file_type_mismatch
```

```
## Warning in request_handler_handler(request = request, handler =
## on_suspect_content, : Event: on_suspect_content
```

```
## 
```

```
## [1] TRUE
```

Begge test-spørringene returnerer SANN, og det bør derfor være tillatt. Det kommer imidlertid også en rekke advarsler her - on_not_found er en hendelse som trigges ved en 404-feil, dvs. "ikke funnet". Kan det dermed tenkes at robots.txt mangler eller ikke er definert som forventa? Eller er det pakka det er noe feil med? 

Et annet alternativ er å bruke [polite-pakka](https://dmi3kno.github.io/polite/), det [anbefales også av tidyverse-Wickham](https://rvest.tidyverse.org/). Hvis en skal lage funksjoner som henter info fra mange nettsider, kan det være lurt. Samtidig tror jeg det viktigste er å ikke overbelaste nettsida, noe som også kan gjøres med å sette godt med Sys.sleep-tid mellom spørringer.



## Rvest 

Rvest er tidyverse-pakka for enkel web-scraping, ifølge [vignetten](https://cloud.r-project.org/web/packages/rvest/vignettes/rvest.html). Eksempelet i vignetten for pakka er basert på en enkel side-struktur:


```r
#fra https://rvest.tidyverse.org/
#les html
starwars <- read_html("https://rvest.tidyverse.org/articles/starwars.html")

#finn elementer som matcher en css-selector eller et xpath-uttrykk
films <- starwars %>% html_elements("section")
films
```

```
## {xml_nodeset (7)}
## [1] <section><h2 data-id="1">\nThe Phantom Menace\n</h2>\n<p>\nReleased: 1999 ...
## [2] <section><h2 data-id="2">\nAttack of the Clones\n</h2>\n<p>\nReleased: 20 ...
## [3] <section><h2 data-id="3">\nRevenge of the Sith\n</h2>\n<p>\nReleased: 200 ...
## [4] <section><h2 data-id="4">\nA New Hope\n</h2>\n<p>\nReleased: 1977-05-25\n ...
## [5] <section><h2 data-id="5">\nThe Empire Strikes Back\n</h2>\n<p>\nReleased: ...
## [6] <section><h2 data-id="6">\nReturn of the Jedi\n</h2>\n<p>\nReleased: 1983 ...
## [7] <section><h2 data-id="7">\nThe Force Awakens\n</h2>\n<p>\nReleased: 2015- ...
```

```r
#hver tittel er tagga med en <h2>, og kan hentes med html_element
#teksten i html-elementet kan så ekstraheres med html_text2

title <- films %>% 
  html_element("h2") %>% 
  html_text2()
title
```

```
## [1] "The Phantom Menace"      "Attack of the Clones"   
## [3] "Revenge of the Sith"     "A New Hope"             
## [5] "The Empire Strikes Back" "Return of the Jedi"     
## [7] "The Force Awakens"
```

```r
rm(starwars, films, title)
```

Tutorial-innføringa i rvest er ganske enkel, og ikke direkte overførbar til Doffin-sida, hvor elementene vi er interessert i ligger på nivå 9 som barnebarns barnebarn e.l. under en hel haug div-tagger. En bør dermed kjenne til xpath for å finne fram.

## En liten omvei om Xpath

Xpath er XML path language, og bruker sti-aktig språk for å finne noder i et xml-dokument. HTML-dokumenter kan dermed også leses med dette språket. W3 har en grei oversikt over syntax og begreper. W3 styrer med dette, og har en god intro til syntaksen [her](https://www.w3schools.com/xml/xpath_intro.asp).


En kan finne xpath i Chrome-konsollet ("inspiser element" -> "elements" -> høyreklikk -> "copy xpath" eller "copy full xpath". Første steg er å hente ut innholdet jeg ønsker meg. Her er litt div. forsøk på å finne fram:


```r
test = read_html("https://doffin.no/Notice")

#denne xpathen velger ting under id-attributten "content", så div-noden under denne, og så tredje article-node under der igjen.

alle_elementer = html_element(test, xpath = "//*[@id='content']/div/article[3]")

#en spesifikk utlsyningstittel burde være det første div/div-elementet her
titler_utlysninger = html_element(alle_elementer, xpath = "div[1]/div[1]")

#tittelen inneholder tittelen og en relativ href til selve utlysningen

#her får jeg også med tags for hr, de trenger jeg ikke

#hva med alle a-elementene?
titler_utlysninger = html_element(alle_elementer, xpath = "//a")

#html_elements gir et større resultat?
titler_utlysninger = html_elements(alle_elementer, xpath = "//a")

#a-taggen kan også brukes?
titler_utlysninger = html_elements(alle_elementer, "a")

#hva med boksen med opplysninger om hver enkelt utlysning?
#burde denne velge alle div-elementer med et class-attributt som er "notice-search-item"?
kun_utlysninger = html_element(alle_elementer, xpath = "//div[@class = 'notice-search-item']")

kun_utlysninger = html_element(alle_elementer, xpath = "//*[@class = 'notice-search-item']")

#jeg klarer ikke å kun velge en, den første

#jeg kan teoretisk manuelt sette opp en velger her som tar enkelt-elementene, 1-10?
spesifikk_utlysning = html_element(alle_elementer, xpath = "//*[@class = 'notice-search-item'][5]")

##i følge chrome er xpath til et element //*[@id="content"]/div/article[3]/div[1]
spesifikk_utlysning = html_element(test, xpath = "//*[@id='content']/div/article[3]/div[5]")

#men da må jeg teste for når jeg går tom
spesifikk_utlysning = html_element(alle_elementer, xpath = "//*[@class = 'notice-search-item'][100]")

#ikke at det er verre enn at lista da blir tom.
#ligger problemet i mellom-steget, tro?
#i følge chrome er xpath til et element //*[@id="content"]/div/article[3]/div[1]
kun_utlysninger = html_element(test, xpath = "//*[@id='content']/div/article[3]/div")

#html_elements
kun_utlysninger = html_elements(test, xpath = "//*[@id='content']/div/article[3]/div")

#konvertere til tekst

#- den spesifikke
spesifikk_utlysning = html_element(test, xpath = "//*[@id='content']/div/article[3]/div[5]") %>%
  html_text2()

#alle
kun_utlysninger = html_elements(test, xpath = "//*[@id='content']/div/article[3]/div") %>%
  html_text2()

#å konvertere alle disse elementene til tekst er ikke så nyttig, den må håndteres på en anna måte.
```

I vignetten forklares et vanlig mønster for rvesting: Først bruke html_elements for å få ut alt, og så html_element for å velge enkelt-klosser som skal utgjøre den enkelte rad eller kolonne. Det er fordi html_element alltid returnerer like mange elementer som du sender inn, og fyller inn med NA. Dermed er den sikrere (hvis f.eks. en av oppføringene mangler et under-element, får den NA, i stedet for å bare mangle uten noen mulighet til å finne ut av hvem som mangler). Ett eksempel: Første gjennomgang ga 11 elementer fra navn, men 10 elementer fra alle de andre elementene. Det var fordi også en av de andre elementene ble tatt med, ikke bare noticene, og hadde et navn.


Det er potensielt problematisk og sårbart ved avvikende formater - jeg veit ikke om alle disse feltene alltid kommer til å være med.

# La oss finne informasjonen vi skal ha!


```r
#alle utlysninger
kun_utlysninger = html_elements(test, xpath = "//*[@id='content']/div/article[3]/div")

#det er mulig jeg fisker med meg for mange ting her
#fordi jeg bruker div til slutt, identifiserer den alle div-elementene, ogdet siste div-elementet er "pagination- ctm-pagination", ikke "notice-search-item
#prøver i stedet
kun_utlysninger = html_elements(test, xpath = "//*[@id='content']/div/article[3]/div[@class = 'notice-search-item']")

#navn
navn = html_elements(kun_utlysninger, xpath = "//div[@class = 'notice-search-item-header']/a") %>%
  html_text()

#html-elements her returnerer 11 objekter, jeg vil ha for alle de funnede objektene
navn = html_element(kun_utlysninger, xpath = "//div[@class = 'notice-search-item-header']/a") %>%
  html_text()

#av en eller annen grunn finner html_element kopier av den første matchen her?
navn = html_element(kun_utlysninger, xpath = "div[@class = 'notice-search-item-header']/a") %>%
  html_text()

#uten // først, som matcher alt?, men i stedet går rett på å søke dem opp, så går det bra? klø-i-hodet
#men neste problem
# denne fintes ut av at oppfølring nr. 10 har to <a> under headeren, der den første lenker til mercell-plattformen. Men jeg vil kun ha den andre. Jeg kan ikke bruke bare de som har href, siden den har det Kan jeg bruke contains og matche på de stedene hvor det lenkes til en doffin-notice? Hvis alle gjør det?
navn = html_element(kun_utlysninger, xpath = "div[@class = 'notice-search-item-header']/a[contains(@href, 'Notice')]") %>%
  html_text()

#lenke til kunngjøring
#den faktiske lenka bør ligge i tittelen/navnet på det som er kunngjort
#da må jeg hente verdien av attributtet?
#det gjøres ved å legge selve attributtet til slutt
#men siden jeg også må partial-matche med contains må den komme før
lenke = html_element(kun_utlysninger, xpath = "div[@class = 'notice-search-item-header']/a[contains(@href, 'Notice')]/@href") %>%
  html_text()

#hvem har publisert
publisert_av = html_element(kun_utlysninger, xpath = "div[@class = 'left-col']/div[1]") %>%
  html_text2()

#kunngjøringstype
kunngjoring_type = html_element(kun_utlysninger, xpath = "div[@class = 'left-col']/div[2]") %>%
  html_text2()

#doffin referanse
doffin_referanse = html_element(kun_utlysninger, xpath = "div[@class = 'right-col']/div[1]") %>%
  html_text2()

#kunngjøringsdato
kunngjoring_dato = html_element(kun_utlysninger, xpath = "div[@class = 'right-col']/div[2]") %>%
  html_text2()

#enda en snag - siste oppfølring her er visst den eneste faktiske konkurransekunngjøringa. 
#den har dermed tre elementer i right-col
#velge last bør fikse.
kunngjoring_dato = html_element(kun_utlysninger, xpath = "div[@class = 'right-col']/div[last()]") %>%
  html_text2()

#tilbudsfrist
#veldig sentralt. på det ene eksempelet her er den inni enda en span, så den bør la seg identifisere?
#men vet ikke hvor robust det er - kan andre ting være inni en span?
tilbudsfrist_dato = html_element(kun_utlysninger, xpath = "div[@class = 'right-col']/div[2]/span") %>%
  html_text2()


#setter sammen datasettet
df = data.frame(
  doffin_referanse, navn, publisert_av, kunngjoring_type, kunngjoring_dato, tilbudsfrist_dato
)

glimpse(df)
```

```
## Rows: 10
## Columns: 6
## $ doffin_referanse  <chr> "Doffin referanse: 2022-385195", "Doffin referanse: ~
## $ navn              <chr> "Dialogmøte - Evaluering av Trøndelag fylkeskommune ~
## $ publisert_av      <chr> "\r Publisert av:\r Trøndelag fylkeskommune\r \r", "~
## $ kunngjoring_type  <chr> "Kunngjøringstype: Veiledende", "Kunngjøringstype: K~
## $ kunngjoring_dato  <chr> "Kunngjøringsdato: 2022-01-25", "Kunngjøringsdato: 2~
## $ tilbudsfrist_dato <chr> NA, "2022-02-14", "2022-02-14", "2022-02-09", NA, "2~
```

Det er første side, med noen caser her. Hva skjer med neste side, og andre enheter? URL-en ser ut til å oppdatere sge på veldig fornuftig vis: URL-en endres fra https://doffin.no/Notice til https://doffin.no/Notice?pageNumber=1&pageSize=10. Altså to egenskaper - sidenummer og sidestørrelse.


# La oss lage noen funksjoner for å få litt mer oversiktlig kode

Dette ser ut til å fungere etter hensikten. Men koden tar litt mye plass, og er ganske gjentakende.

Først to funksjoner, en for å lage URL og en for å hente ut de ønskede dataene fra søkeresultatet.


```r
#doffin_url_builder
#definerer funksjonen som en i utgangspunktet tom funksjon, kun sidenummer, antall resultater pr side, og sortering etter kunngjøringsdato. isadvancedsearch og includeexpired er false.
#CamelCase

#argumenter
#query: "Direktoratet+for+høyere+utdanning+og+kompetanse+(HK-dir)"',
#PageNumber: sidenummer, brukt over
#PageSize:  hvor mange treff pr side
#&OrderingType: 0 - relevans, 1 - kunngjøringsdato, 2 - tilbudsfrist, 3 - doffin-referanse, 4 - tittel, 5 - publisert av
#OrderingDirection:  0 - stigende, 1 - synkende
#RegionId:  div geokoder på regionnivå
#CountyId: div goekoder på flkenivå
#MunicipalityId. div geokoder på kommunenivå
#IsAdvancedSearch: true hvis du inkluderer overliggende regioner , false som standard
#location:  usikker på denne, kanskje en kombo av geokodene?
#NoticeType:  kunngjøringstype - blank = alle, 1 = veiledende, 2 = kunngjøring av konkurranse, 3 = tildeling, 4 = intensjonskunngjøring, 6 = kjøperprofil, 999999 = Dynamisk innkjøpsprofil.
#PublicationType: blank = alle, 1 = nasjonal, 2 = europeisk, 5 = market consulting
#IncludeExpired: #skal utgåtte inkluderes? true hvis ja, false hvis nei
#Cpvs: CPV-koder her - flere bindes sammen med + , eksempel: Cpvs=34000000+33000000
#EpsReferenceNr: Doffin referanse-nr.
#DeadlineFromDate; tilbudsfrist fra, formateres 01.01.2022 DD.MM.ÅÅÅÅ
#DeadlineToDate: tilbudsfrist til, formateres 01.02.2022
#PublishedFromDate: #kunngjøringsdato fra, formateres 01.02.2022
#PublishedToDate: #kunngjøringsdato til, formaters også 01.02.2022

doffin_url_builder = function(Query = "", PageNumber = "1", PageSize = "100", OrderingType = "1", OrderingDirection = "1", RegionId = "", CountyId = "", MunicipalityId = "", IsAdvancedSearch = "false", Location = "", NoticeType = "", PublicationType = "", IncludeExpired = "false", Cpvs = "", EpsReferenceNr = "", DeadlineFromDate = "", DeadlineToDate = "", PublishedFromDate = "", PublishedToDate = ""){
  temp_url = paste0("https://doffin.no/Notice?",
        "query=", Query,
        "&PageNumber=", PageNumber,
        "&PageSize=", PageSize,
        "&OrderingType=", OrderingType, 
        "&OrderingDirection=", OrderingDirection, 
        "&RegionId=", RegionId,
        "&CountyId=", CountyId,
        "&MunicipalityId=", MunicipalityId,
        "&IsAdvancedSearch=", IsAdvancedSearch,
        "&location=", Location,
        "&NoticeType=", NoticeType,
        "&PublicationType=", PublicationType,
        "&IncludeExpired=", IncludeExpired,
        "&Cpvs=", Cpvs,
        "&EpsReferenceNr=", EpsReferenceNr,
        "&DeadlineFromDate=", DeadlineFromDate,
        "&DeadlineToDate=&", DeadlineToDate,
        "PublishedFromDate=", PublishedFromDate,
        "&PublishedToDate=", PublishedToDate
  )
}

#doffin_fetch_results
#en funksjon som tar en doffin-query-url som input, og returnerer resultatet som en data.frame
#basert på rvest-pakken

doffin_fetch_results = function(url){
  #henter html-fil
  temp_html = read_html(url)
  #henter ut kun utlysninger fra html-fila
  kun_utlysninger = html_elements(temp_html, 
                                  xpath = "//*[@id='content']/div/article[3]/div[@class = 'notice-search-item']")
  #setter sammen datasettet
  temp_df = data.frame(
    doffin_referanse = html_element(kun_utlysninger, 
                                    xpath = "div[@class = 'right-col']/div[1]") %>%
      html_text2(), 
    navn = html_element(kun_utlysninger, 
                        xpath = "div[@class = 'notice-search-item-header']/a[contains(@href, 'Notice')]") %>%
      html_text2(),
    publisert_av = html_element(kun_utlysninger, xpath = "div[@class = 'left-col']/div[1]") %>%
      html_text2(),
    kunngjoring_type = html_element(kun_utlysninger, xpath = "div[@class = 'left-col']/div[2]") %>%
      html_text2(), 
    kunngjoring_dato = html_element(kun_utlysninger, xpath = "div[@class = 'right-col']/div[last()]") %>%
      html_text2(), 
    tilbudsfrist_dato = html_element(kun_utlysninger, xpath = "div[@class = 'right-col']/div[2]/span") %>%
      html_text2(), 
    lenke = html_element(kun_utlysninger, 
                         xpath = "div[@class = 'notice-search-item-header']/a[contains(@href, 'Notice')]/@href") %>%
      html_text()
  )
}
```

Denne funksjonen har en del forbedringspotensiale:

- hvis lista kun_utlysninger er like lang som PageSize, er det fare for at det er flere sider med resultater. Dette burde en advare om, og ideelt sett også håndtere. Kjapp kikk på det:


```r
url = doffin_url_builder()
temp_html = read_html(url)
#henter pagineringselementet
paginering = html_elements(temp_html, 
                         xpath = "//*[@id='content']/div/article[3]/div[101]")
#henter sidetallet fra denne, trekker ut teksten, og konverterer tallet til et tall.
antall_sider = html_element(paginering, xpath = "ul[2]/li[3]") %>%
  html_text2() %>%
  parse_number(.)
```

- Query-argumentet bør ha noe for å sjekke at strengen er korrekt definert (med + i stedet for mellomrom, evt "" hvis strengt søk)
- Hvis det skal brukes i en loop - feilhåndtering?

Men på denne måten kan spørringene skrives langt mer kompakte. 

## Hente siste kunngjøringer

Standard-søket blir da slik:


```r
url = doffin_url_builder()
resultater = doffin_fetch_results(url)
```

## Loope gjennom en liste av kunder

Her er et eksempel, med alle ikke-utgåtte kunngjøringer av konkurranser fra noen offentlige oppdragsgivere:


```r
#merk %22 er HTML for "", de trengs her og der for å få treff.
#stoler ikke 100 % på denne.

kunder = c(
  "Viken+fylkeskommune",
  "Arbeids-+og+inkluderingsdepartementet",
  "NAV",
  "Bergen+kommune",
  "%22Barne-,+ungdoms-+og+familiedirektoratet%22",
  "Digitaliseringsdirektoratet",
  "Direktoratet+for+forvaltning+og+økonomistyring+(DFØ)",
  "%22Direktoratet+for+høyere+utdanning+og+kompetanse+(HK-dir)%22",
  "Distriktssenteret",
  "Integrerings-+og+mangfoldsdirektoratet+(IMDi)",
  "Husbanken"
)

resultater = data.frame()

for(i in 1:length(kunder)){
  url = doffin_url_builder(Query = kunder[i], NoticeType = "2")
  temp_resultater = doffin_fetch_results(url)
  if(nrow(temp_resultater) == 0){
    message("ingen funn for ", i, " - ", kunder[i])
  }
  if(nrow(temp_resultater) > 0){
    temp_resultater$`søk` = kunder[i]
    resultater = bind_rows(resultater, temp_resultater)
    message("ferdig med ", i, ", ", kunder[i])
  }
  Sys.sleep(5)
}
```

```
## ferdig med 1, Viken+fylkeskommune
```

```
## ferdig med 2, Arbeids-+og+inkluderingsdepartementet
```

```
## ferdig med 3, NAV
```

```
## ferdig med 4, Bergen+kommune
```

```
## ferdig med 5, %22Barne-,+ungdoms-+og+familiedirektoratet%22
```

```
## ferdig med 6, Digitaliseringsdirektoratet
```

```
## ferdig med 7, Direktoratet+for+forvaltning+og+økonomistyring+(DFØ)
```

```
## ingen funn for 8 - %22Direktoratet+for+høyere+utdanning+og+kompetanse+(HK-dir)%22
```

```
## ingen funn for 9 - Distriktssenteret
```

```
## ferdig med 10, Integrerings-+og+mangfoldsdirektoratet+(IMDi)
```

```
## ferdig med 11, Husbanken
```

```r
glimpse(resultater)
```

```
## Rows: 166
## Columns: 8
## $ doffin_referanse  <chr> "Doffin referanse: 2022-341056", "Doffin referanse: ~
## $ navn              <chr> "Anskaffelse av totalentreprenør til ny fendringsløs~
## $ publisert_av      <chr> "\r Publisert av:\r Viken fylkeskommune \r", "\r Pub~
## $ kunngjoring_type  <chr> "Kunngjøringstype: Kunngjøring av konkurranse", "Kun~
## $ kunngjoring_dato  <chr> "Kunngjøringsdato: 2022-01-24", "Kunngjøringsdato: 2~
## $ tilbudsfrist_dato <chr> "2022-02-25", "2022-02-07", "2022-02-08", "2022-02-0~
## $ lenke             <chr> "/Notice/Details/2022-341056", "/Notice/Details/2022~
## $ søk               <chr> "Viken+fylkeskommune", "Viken+fylkeskommune", "Viken~
```

5 sekunders Sys.sleep-tid bør være bra.
 
## Kunngjøring av konkurranser etter CPV

Før vi ser på muligheten for å hente mer informasjon enn det som ligger i oppslaget, la oss bare ta et kjapt søk som sammenfatter siste ukes kunngjøringer av konkurranser på en sentral CPV:


```r
fradato = format(Sys.Date() - 7, "%d.%m.%Y")
tildato = format(Sys.Date(), "%d.%m.%Y")

url = doffin_url_builder(
  NoticeType = "2",
  Cpvs = "73000000", 
  PublishedFromDate = fradato, 
  PublishedToDate = tildato)

resultater = doffin_fetch_results(url)

glimpse(resultater)
```

```
## Rows: 12
## Columns: 7
## $ doffin_referanse  <chr> "Doffin referanse: 2022-372145", "Doffin referanse: ~
## $ navn              <chr> "Rapport om innvandreres innenlandske flytting", "An~
## $ publisert_av      <chr> "\r Publisert av:\r Kommunal- og distriktsdepartemen~
## $ kunngjoring_type  <chr> "Kunngjøringstype: Kunngjøring av konkurranse", "Kun~
## $ kunngjoring_dato  <chr> "Kunngjøringsdato: 2022-01-24", "Kunngjøringsdato: 2~
## $ tilbudsfrist_dato <chr> "2022-02-14", "2022-02-22", "2022-02-14", "2022-02-2~
## $ lenke             <chr> "/Notice/Details/2022-372145", "/Notice/Details/2022~
```

## Hente ut mer informasjon fra selve kunngjøringen

Jeg har URL til kunngjøringen, og kan dermed hente informasjon herifra.


```r
url = doffin_url_builder(Query = "IMDi", NoticeType = "2")
temp_resultater = doffin_fetch_results(url)

#denne kan fjerne info
test = str_remove(temp_resultater[1,1], fixed("Doffin referanse: "))

#men vi har jo lenka
mer_info <- read_html(paste0("https://doffin.no", temp_resultater[1,7]))
cpv = html_elements(mer_info, xpath = "//*[@id='notice']/div[3]/div[2]/div[5]/div/span") %>%
  html_text2()

#er det samme mønster på en anna en?
mer_info <- read_html(paste0("https://doffin.no", temp_resultater[3,7]))
cpv = html_elements(mer_info, xpath = "//*[@id='notice']/div[3]/div[2]/div[5]/div/span") %>%
  html_text2()
#kort beskrivelse også?
beskrivelse = html_elements(mer_info, xpath = "//*[@id='notice']/div[3]/div[2]/div[9]/div") %>%
  html_text2()

#vi looper igjennom litt flere samtidig!

for(i in 1:nrow(temp_resultater)){
  mer_info <- read_html(paste0("https://doffin.no", temp_resultater[i,7]))
  temp_resultater$cpv[i] = html_elements(mer_info, xpath = "//*[@id='notice']/div[3]/div[2]/div[5]/div/span") %>%
  html_text2()
  temp_resultater$beskrivelse[i] = html_elements(mer_info, xpath = "//*[@id='notice']/div[3]/div[2]/div[9]/div") %>%
  html_text2()
  Sys.sleep(5)
}

glimpse(temp_resultater)
```

```
## Rows: 6
## Columns: 9
## $ doffin_referanse  <chr> "Doffin referanse: 2022-349323", "Doffin referanse: ~
## $ navn              <chr> "Konsulenttjenester for videreutvikling av nettsider~
## $ publisert_av      <chr> "\r Publisert av:\r Integrerings- og mangfoldsdirekt~
## $ kunngjoring_type  <chr> "Kunngjøringstype: Kunngjøring av konkurranse", "Kun~
## $ kunngjoring_dato  <chr> "Kunngjøringsdato: 2022-01-22", "Kunngjøringsdato: 2~
## $ tilbudsfrist_dato <chr> "2022-02-28", "2022-02-14", "2022-01-26", "2022-02-0~
## $ lenke             <chr> "/Notice/Details/2022-349323", "/Notice/Details/2022~
## $ cpv               <chr> "72212224", "73000000", "73110000", "73000000", "731~
## $ beskrivelse       <chr> "Integrerings- og mangfoldsdirektoratet (IMDi) invit~
```

Virker dette også hvis jeg henter de 100 siste kunngjøringene, uavhengig av type, oppdragsgiver, mm? Det kan godt være. Legger inn en liten if-setning for å unngå nullfunn. Fikk en feil her, på /Notice/Details/2022-312872, som mangler denne beskrivelsen. Den er p.t. ikke håndtert.


```r
url = doffin_url_builder()
temp_resultater = doffin_fetch_results(url)

for(i in 1:nrow(temp_resultater)){
  mer_info <- read_html(paste0("https://doffin.no", temp_resultater[i,7]))
  temp_cpv = html_element(mer_info, xpath = "//*[@id='notice']/div[3]/div[2]/div[5]/div/span") %>%
  html_text2()
  if(length(temp_cpv) > 0){
    temp_resultater$cpv[i] = temp_cpv
  }
  if(length(temp_cpv) == 0){
    temp_resultater$cpv[i] = NA
  }
  temp_beskrivelse = html_element(mer_info, xpath = "//*[@id='notice']/div[3]/div[2]/div[9]/div") %>%
  html_text2()
  if(length(temp_beskrivelse) > 0){
    temp_resultater$beskrivelse[i] = temp_beskrivelse
  }
  if(length(temp_beskrivelse) == 0){
    temp_resultater$beskrivelse[i] = NA
  }
  Sys.sleep(5)
}
```


# Mulige videreutviklinger

For å automatisere kjøring av script, er det flere på internett som anbefaler pakka [taskscheduleR](https://cran.r-project.org/web/packages/taskscheduleR/vignettes/taskscheduleR.html).Da trenger vi en kompakt versjon av dette som et script. Har så langt ikke fått det til å virke.

For å få tilsendt varsel på epost, virker pakken mailR virker relevant - https://www.rdocumentation.org/packages/mailR/versions/0.8. Oppretter en test-epostadresse i Google. MailR krever rJava, som igjen krever at Java er installert på maskinen. For å bruke Google-kontoen, må en aktivere sikkerhetsinnstillingen som åpner for "mindre trygger apper". Så ikke gjør dette med en alvorlig epostadresse, kanskje?

### Gjenstående ting å se på

- Teste funnene fra robot-søk mot manuelle søk - er det noe som forsvinner for roboten?
- Sikker berikelse med beskrivelse og cvp fra selve kunngjøringen for ulike edgecaser?
-- "Warning in temp_resultater$beskrivelse[i] <- temp_beskrivelse : number of items to replace is not a multiple of replacement length"
- Hva er fornuftige søkestrenger og cpv-er? M.a.o.: hvilke kunngjøringer er det vi er interessert i? 
- Automatisk kjøring i script-form
- Resultater på epost
- Jeg får advarsler om at "closing unused connection n (url)". Verdt å ta en titt på [stackoverflow](https://stackoverflow.com/questions/37839566/how-do-i-close-unused-connections-after-read-html-in-r) her?  
- hvis lista kun_utlysninger er like lang som PageSize, er det fare for at det er flere sider med resultater. Dette burde en advare om, og ideelt sett også håndtere. 
- Query-argumentet bør ha noe for å sjekke at strengen er korrekt definert (med + i stedet for mellomrom, evt "" hvis strengt søk)
