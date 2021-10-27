---
title: 'En ny kikk på strømforbruk med R'
author: Eivind
date: '2021-10-13'
slug: []
categories: []
tags: []
meta_img: images/image.png
description: Description for the page
---

__Hva handler denne artikkelen om?__ _De høye strømprisene har de siste ukene vært på alle lepper, avisforsider og sakskart. I hvert fall om en skal tro oppstusset i media. Det er en god anledning til å se på forbruket i det nye huset vårt, og få litt grep om hvor høyt og dyrt strømforbruket er_ 



```r
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(janitor))
```

```
## Warning: package 'janitor' was built under R version 4.1.1
```

```r
library(readxl)

#settings
theme_set(theme_minimal())
set.seed(1106)
options(scipen = 100)
```

For å komme til bunns i dette starter jeg med å hente forbruksdataene for målepunktet fra [elhub.no](https://www.elhub.no/). 


```r
#data
files= list.files(path = "data", pattern = "*.csv", full.names = TRUE) 
df = map_df(files, read_delim, delim = ",", escape_double = FALSE,
  skip = 1,
  col_names = c("fra", "til", "forbruk"),
  col_types = cols(
    fra = col_datetime(format = "%d.%m.%Y %H:%M"), 
    til = col_datetime(format = "%d.%m.%Y %H:%M")
    ), 
  locale = locale(decimal_mark = ",", grouping_mark = ""), 
  trim_ws = TRUE)

#tester om det finnes duplikater her
duplikater = get_dupes(df, fra, til)
```

```
## No duplicate combinations found of: fra, til
```

```r
rm(duplikater, files)

#legger til informasjon om datoer

df = mutate(df,
  dato = as.Date(fra),
  time = lubridate::hour(fra),
  dag = lubridate::wday(fra, label = TRUE, abbr = FALSE),
  ukedag = ifelse(dag %in% c("lørdag", "søndag"), "helg", "arbeidsdag"),
  uke = lubridate::week(fra),
  month = lubridate::month(fra),
  natt = ifelse(time %in% c(23, 00, 01, 02, 03, 04, 05), "natt", "dag")
)
```

Kilowatt-time er begrepet en må forholde seg til i denne sammenhengen. En kilowatt-time er måleenheten for å måle energi, og 1 kilowatt-time tilsvarer energien som en effekt på 1 kilowatt utvikler på 1 time.

Her ser jeg at gjennomsnittsforbruket ligger på ca. 19 kilowatt-timer (kwt) pr. døgn, eller 810 watt per time. Det vil da tilsvare at vi har stående på 13,5 lyspærer på 60 watt hele døgnet (og ingenting annet). 


```
##    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
##   3.924  14.222  19.451  19.240  24.449  40.355
```

Sist jeg kikket på dette ([del 1](https://suppe-og-analyse.netlify.app/blog/kan-en-fikse-str%C3%B8mforbruket-analytisk/) og [del 2](https://suppe-og-analyse.netlify.app/blog/str%C3%B8mforbruket-del-2-priser/)) lærte jeg at  strømforbruket varierer mye fra dag til dag, men 

- det er gjerne topper på morgenen rundt kl. 8 og ettermiddagen (rundt kl. 16-18), 
- det er større variasjoner i helgene, men tendenser til jevnt høyere forbruk,
- når det blir kaldere, bruker en mer strøm - men også variasjonen i forbruket øker,


```r
ggplot(data = df, aes(x = time, y = forbruk, colour = ukedag)) +
  geom_smooth() +
  scale_x_continuous(breaks = seq(0, 24, 2)) +
  labs(x = "Tid på døgnet", y = "Forbruk (kwt)", title = "Strømforbruket er høyest om morgenen og ettermiddagen", subtitle = "I hvert fall på hverdagene - i helgene er det på dagtid")
```

```
## `geom_smooth()` using method = 'gam' and formula 'y ~ s(x, bs = "cs")'
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-4-1.png" width="672" />

```r
ggplot(data = df, aes(x = fra, y = forbruk)) +
  geom_point(alpha = 0.2) +
  geom_smooth() +
  labs(x = "Forbrukstidspunkt", y = "Forbruk (kwt)", title = "Høyere strømforbruk utover høsten", subtitle = "Fra 0,75 kwt pr time i august til 1,5 kwt/time i oktober")
```

```
## `geom_smooth()` using method = 'gam' and formula 'y ~ s(x, bs = "cs")'
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-4-2.png" width="672" />

For å forstå dette litt bedre, noterte jeg meg over noen dager tidspunktene hvor vi satte på vaskemaskin, oppvaskmaskin og dusjen:


```r
apparatbruk <- read_excel("data/apparatbruk.xlsx", col_types = c("date", "text"))

temp = filter(df, dato > "2021-10-13" & dato < "2021-10-18") %>%
  left_join(., apparatbruk, by = c("fra" = "Tid"))

ggplot(data = temp, aes(x = fra, y = forbruk)) +
  geom_line() +
  geom_point(data = filter(temp, is.na(Hendelse) == FALSE), aes(x = fra, y = forbruk, colour = Hendelse))
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-5-1.png" width="672" />

De fleste hendelsene kommer sammen med en stigning i forbruket, naturlig nok. Men for at dette skulle gitt mer mening, burde jeg nok ha notert litt mer - med kun 7 datapunkter blir det rett og slett litt fattig for å forstå alle svingningene. Jeg er heller ikke helt sikker på hva vi gjorde som utløste de store toppene rundt kl. 16.00 torsdag 14. oktober og kl. 8 søndag 17. oktober. Oppvarming i kombinasjon med matlaging og barne-TV på søndag?  

# Men hva så? 

## Strømforbruket om natta?

Dette er jo greit nok, og det er morsomme data å leke seg med. Men hva er implikasjonen? Finner jeg noe her som gir meg noe å gå på for å bruke mindre strøm? Kan en for eksempel si at strømbruk om natta bør være lav - og så se om vi holder oss til det?


```r
temp = filter(df, natt == "natt") %>%
  mutate(natt_til = as.Date(fra + (60*60*1))) %>% #for å få gruppert datoene riktig må jeg legge til litt tid her
  group_by(natt_til) %>%
  summarise(forbruk = sum(forbruk))

ggplot(data = temp, aes(x = natt_til, y = forbruk)) +
  geom_line() +
  geom_smooth() +
  labs(x = "Dato", y = "Forbruk (kwt)", title = "Strømforbruket om natta stiger når været blir kaldere")
```

```
## `geom_smooth()` using method = 'loess' and formula 'y ~ x'
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-6-1.png" width="672" />

Ikke spesielt overraskende, kanskje - men strømforbruket natterstid er større når temperaturen faller. Men det er ikke store summer vi snakker om - fra kanskje 1 kwt til rundt 6 kwt. Til sammenlikning ligger forbruket på dagtid rundt 15-16 kwt i snitt i samme periode, og øker opp 25-35 mot slutten av perioden her. Men det er jo også flere timer dag enn natt, i hvert fall slik jeg har definert det over.




## Unormalt høyt strømforbruk?

Kan en i stedet se og flagge tidspunkt hvor strømforbruket har blitt unormalt høyt over en dag? Vel, også her er det en sterk økning i forbruket inn i oktober.


```r
temp = group_by(df, dato) %>%
  summarise(forbruk = sum(forbruk))

ggplot(data = temp, aes(x = dato, y = forbruk)) +
  geom_line() +
  labs(x = "Forbrukstidspunkt", y = "kilowatt-timer forbruk")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-8-1.png" width="672" />

For å identifisere et avvik, må jeg altså først identifisere trenden, og så avviket isolert fra det. Dermed må vi inn i dekomponering igjen, som vi også forsøkte sist med blandede resultater - så da lar jeg det ligge. 

Sagt på en anna måte: strømdataene i seg selv forteller deg ikke om du bruker for mye eller for lite strøm. En god gammeldags gjennomgang av hvilke apparater som står på når - særlig ovner - vil en nok komme lengre med.
 

