#Script som bygger sida

#pakker
library(blogdown)

#setter opp ny side
#bruker tanka-theme https://github.com/nanxstats/hugo-tanka

new_site(theme = "nanxstats/hugo-tanka")

#setter noen settings i Rprofile-fila
blogdown::config_Rprofile() 

#noen kontroller

check_gitignore()

check_content()

check_netlify()

check_hugo()

#får et problem med at siden av og til ikke finner config.yaml. 
#blogdown:::site_root() gir da ".", i stedet for den faktiske rota "[1] "C:/Users/Kauna/OneDrive/Documents/R/datablog_v002"
#""

#får også et problem med at den ikke gjenkjenner nordiske tegn når jeg kjører Rstudio-addinen.

#kan jeg løse det ved å bruke script-kommandoer i stedet for å bruke add-in?

#serve site
serve_site()

#ny post
#unngå æ-ø-å i tittelen her
new_post(
  title = "Age of Empires",
)

#stop server
stop_server()