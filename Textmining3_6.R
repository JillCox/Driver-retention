#bring in the data from a stored procedure in sql
library(RODBC)
library(stringr)
dbhandle_CIP <- odbcDriverConnect('driver={SQL Server};server=CTG-SQLAAG02;database=CIP;uid=CVEN\\coxjil;pwd=myChristian352;trusted_connection=yes')
string_SurveyAnalytics<- sprintf("EXEC dbo.sp_SurveyAnalytics")
string_SurveyAnalytics<- str_replace_all(string_SurveyAnalytics, "[\r\n]", " ")
SurveyAnalytics<- sqlQuery(dbhandle_CIP, (string_SurveyAnalytics), as.is=TRUE)
#put every word into its own line
#remove stop words
library(tidytext)
library(dplyr)
Word_by_Word <- SurveyAnalytics %>% 
  unnest_tokens(word, whyleft) %>% 
  anti_join(stop_words)
#count the most common words on the whole
popular<- Word_by_Word %>%
  count(word, sort = TRUE)
#create a vector of words that are not useful in the count
#remove our stop words
why_left<- Word_by_Word[! (Word_by_Word$word %in% c("driver", "pro", "drivers", "driving", "covenant", "drive", "3", "company")),]
#count the most common words
popular_words <- why_left %>%
  count(word, sort = TRUE)
#plot the results in a bar chart
library(ggplot2)
why_left %>%
  count(word, sort = TRUE) %>%
  filter(n> 10) %>%
  mutate(word = reorder(word, n)) %>%
  ggplot(aes(word, n)) +
  geom_col()+
  xlab(NULL) +
  coord_flip()
#sort results into word groups based on underlying problem
why_left$word[why_left$word %in% c("home", "time", "family", "emergency", "week", "weeks", "road", "days", "day")] <- "familyneeds"
why_left$word[why_left$word %in% c("team", "solo", "truck", "hazmat")] <- "teamissues"
why_left$word[why_left$word %in% c("pay", "paid", "money", "issue", "payroll", "miles", "issues", "lot")] <- "expectations"
why_left$word[why_left$word %in% c("manager", "fleet", "dispatch", "dispatcher")] <- "communication"
why_left$word[why_left$word %in% c("trainer", "training")] <- "training"
#sort seniority into time periods
why_left$seniority<- ifelse(why_left$seniority <=6, "<6",
                            ifelse(why_left$seniority >6 & why_left$seniority <=12, "1 year",
                                   ifelse(why_left$seniority >12 & why_left$seniority <=24, "2 year",
                                          ifelse (why_left$seniority >24 & why_left$seniority <=60, "2-5 years",
                                          ifelse (why_left$senioirty >60, "5+", "5+")))))
#sort CVENtime into time periods
why_left$CVENtime<- ifelse(why_left$CVENtime <=6, "<6",
                            ifelse(why_left$CVENtime >6 & why_left$CVENtime <=12, "1 year",
                                   ifelse(why_left$CVENtime >12 & why_left$CVENtime <=24, "2 year",
                                          ifelse (why_left$CVENtime >24 & why_left$CVENtime <=60, "2-5 years",
                                                  ifelse (why_left$CVENtime >60, "5+", "Unknown")))))

#create a word cloud visual
library(wordcloud)
why_left %>% 
  anti_join(stop_words) %>%
  count(word) %>%
  with(wordcloud(word, n, max.words = 50)) 


# create a word cloud where posivie words are grey and negative words are black
library(reshape2)

why_left %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  acast(word ~ sentiment, value.var = "n", fill = 0) %>%
  comparison.cloud(colors = c("gray80", "gray20"),
                   max.words = 100)

#do the same process for why they liked about covenant
#remove stop words
Word_by_Word2 <- SurveyAnalytics %>% 
  unnest_tokens(word, whatsgood) %>% 
  anti_join(stop_words)

#count the most common words on the whole
popular<- Word_by_Word2 %>%
  count(word, sort = TRUE)
#create a vector of words that are not useful in the count
#remove our stop words
whatsgood<- Word_by_Word2[! (Word_by_Word2$word %in% c("driver", "pro", "drivers", "driving", "covenant", "drive", "3", "company")),]
#count the most common words
popular_words <- whatsgood %>%
  count(word, sort = TRUE)
#plot the results in a bar chart
library(ggplot2)
whatsgood %>%
  count(word, sort = TRUE) %>%
  filter(n> 10) %>%
  mutate(word = reorder(word, n)) %>%
  ggplot(aes(word, n)) +
  geom_col()+
  xlab(NULL) +
  coord_flip()
#create word cloud
library(wordcloud)
whatsgood %>% 
  anti_join(stop_words) %>%
  count(word) %>%
  with(wordcloud(word, n, max.words = 50)) 
