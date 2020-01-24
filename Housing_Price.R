library(recipes)
library(olsrr)
library(tidyverse)
library(pander)
library(recipes)
library(tidyverse)
library(stringr)
library(forcats)
library(tidyquant)

train_df <- read_csv("Data/training.csv")
test_df <- read_csv("Data/validation.csv")


data_process <- function(data, train = T, test = F, cor_df = F){
  
  #convert into factor
  df <- data %>%
      mutate(MSSubClass = as.factor(MSSubClass),
             OverallCond = as.factor(OverallCond),
             YrSold = as.factor(YrSold), 
             MoSold = as.factor(MoSold),
             OverallQual = as.factor(OverallQual))
  
  #fill NA's With None ----
  NA_cols_None <- c("PoolQC",
                    "MiscFeature",
                    "Alley",
                    "Fence",
                    "FireplaceQu",
                    "GarageType",
                    "GarageFinish",
                    "GarageQual",
                    "GarageCond",
                    "BsmtQual",
                    "BsmtCond",
                    "BsmtExposure",
                    "BsmtFinType1",
                    "BsmtFinType2",
                    "MasVnrType",
                    "MSSubClass")
  
  df[,NA_cols_None][is.na(df[,NA_cols_None])] <- "None"
  
  #fill NA's with median of LotFrontage of Neighborhood ----
  df <- df %>%
    group_by(Neighborhood) %>%
    mutate(LotFrontage = replace_na(LotFrontage, replace = median(LotFrontage, 
                                                                  na.rm = T))) %>%
    ungroup()
  
  
  #fill NA's with 0 ----
  NA_cols_0 <- (c(
    "GarageYrBlt",
    "GarageArea",
    "GarageCars",
    "BsmtFinSF1",
    "BsmtFinSF2",
    "BsmtUnfSF",
    "TotalBsmtSF",
    "BsmtFullBath",
    "BsmtHalfBath",
    "MasVnrArea"
  ))
  
  df[,NA_cols_0][is.na(df[,NA_cols_0])] <- 0
  
  #fill NA's with most frequently appear ----
  df <- df %>%
    mutate(Electrical = str_replace_na(string = Electrical, replacement = "SBrkr")) 
    
  if(train){
    
    return(
      
      df %>%
           #filter outlier ----  
           filter(GrLivArea < 4000) %>% 
        
        mutate(
          YearBuilt = ifelse(YearBuilt >= 1950, "New", "Old"),
      #Transform SalePrice into LogSalePrice ----
          Log_Sale_Price = log(SalePrice),
      #Create New Variable for TotalBathroom ----
          Total_Bathroom = BsmtFullBath + BsmtHalfBath + FullBath + HalfBath) %>%
        
        select(
          GrLivArea, GarageArea, TotalBsmtSF, TotRmsAbvGrd, BedroomAbvGr,
          YearBuilt, ExterQual, Neighborhood, BldgType, OverallQual, 
          HeatingQC, Total_Bathroom, Log_Sale_Price))
  }
  
  if(test){
    
    return(
      
      df %>%
        mutate(
          
          YearBuilt = ifelse(YearBuilt >= 1950, "New", "Old"),
      #Transform SalePrice into LogSalePrice ----
          Log_Sale_Price = log(SalePrice),
      #Create New Variable for TotalBathroom ----
          Total_Bathroom = BsmtFullBath + BsmtHalfBath + FullBath + HalfBath) %>%
        
        select(
          GrLivArea, GarageArea, TotalBsmtSF, TotRmsAbvGrd, BedroomAbvGr,
          YearBuilt, ExterQual, Neighborhood, BldgType, OverallQual, 
          HeatingQC, Total_Bathroom, Log_Sale_Price))
  }
  
  if(cor_df){
    
    return(
      df %>%
        mutate(Log_Sale_Price = log(SalePrice))
    )
  }
    
}

# run data_process function on train data
train_processed <- data_process(train_df,train = T)
plot_data <- data_process(train_df, train = F, test = F, cor_df = T)


#create dummy variables for all the nominal variables except variable "overallQual"
rec_obj <- recipe(Log_Sale_Price~., data = train_processed) %>%
  step_dummy(all_nominal(), -OverallQual) %>%
  prep()

#summary(rej_obj)

train_processed_model <- bake(rec_obj, new_data = train_processed)



p1_saleprice_Hist <- plot_data %>%
  ggplot(aes()) +
  geom_histogram(aes(SalePrice), fill = "blue", 
                 color = "black", bins = 30)  +
  theme_bw() +
  labs(y = NULL, x = "Sale Price")

#QQ plot of SalePrice

p1_saleprice_QQ  <- plot_data %>%
  ggplot(aes(sample = SalePrice)) +
  stat_qq() +
  stat_qq_line() + 
  theme_bw() +
  labs(y = "Sale Price")


#Histogram of log SalePrice

p2_log_saleprice_Hist <- plot_data %>%
  ggplot(aes()) +
  geom_histogram(aes(Log_Sale_Price), fill = "blue", 
                 color = "black", bins = 30)  +
  theme_bw() +
  labs(y = NULL, x = "Log Sale Price")

#QQ plot of log SalePrice

p2_log_saleprice_QQ  <- plot_data %>%
  ggplot(aes(sample = Log_Sale_Price)) +
  stat_qq() +
  stat_qq_line() + 
  theme_bw() +
  labs(y = "Log Sale Price")




cowplot::plot_grid(p1_saleprice_Hist, p1_saleprice_QQ,
                   p2_log_saleprice_Hist, p2_log_saleprice_QQ,
                   ncol = 2)


p1_outlier <- plot_data %>%
  ggplot(aes(GrLivArea, SalePrice)) +
  geom_point() +
  geom_vline(xintercept = 4000, color = "red") +
  theme_bw() +
  labs(title = "before removed ouliters") 


p2_outlier <- plot_data %>%
  filter(GrLivArea < 4000) %>%
  ggplot(aes(GrLivArea, SalePrice)) +
  geom_point() +
  theme_bw() +
  labs(title = "after removed ouliters") 

cowplot::plot_grid(p1_outlier, p2_outlier)


train_processed %>%
  ggplot(aes(GrLivArea, Log_Sale_Price)) +
  geom_point() +
  geom_smooth(se = F, method = "lm") +
  labs(x = "Above the ground living area square feet",
       y = "Log of Sale Price") +
  theme_bw()



p1 <- train_processed %>%
  ggplot(aes(HeatingQC)) +
  geom_bar(fill = 'blue') +
  labs(x = "HeatingQC", y = "Log SalePrice") +
  theme_bw()


p2 <- train_processed %>%
  ggplot(aes(GarageArea, Log_Sale_Price)) +
  geom_point() +
  geom_smooth(se = F, method = "lm") +
  labs(x = "Garage Area",
       y =  NULL) +
  theme_bw()

cowplot::plot_grid(p1,p2,label_x = "Log SalePrice")


get_cor <- function(data, target, use = "pairwise.complete.obs",
                    fct_reorder = FALSE, fct_rev = FALSE) {
    
    feature_expr <- enquo(target)
    feature_name <- quo_name(feature_expr)
    
    data_cor <- data %>%
        mutate_if(is.character, as.factor) %>%
        mutate_if(is.factor, as.numeric) %>%
        cor(use = use) %>%
        as_tibble() %>%
        mutate(feature = names(.)) %>%
        select(feature, !! feature_expr) %>%
        filter(!(feature == feature_name)) %>%
        mutate_if(is.character, as_factor)
    
    if (fct_reorder) {
        data_cor <- data_cor %>% 
            mutate(feature = fct_reorder(feature, !! feature_expr)) %>%
            arrange(feature)
    }
    
    if (fct_rev) {
        data_cor <- data_cor %>% 
            mutate(feature = fct_rev(feature)) %>%
            arrange(feature)
    }
    
    return(data_cor)
    
}

plot_cor <- function(data, target, fct_reorder = FALSE, fct_rev = FALSE, 
                     include_lbl = TRUE, lbl_precision = 2, lbl_position = "outward",
                     size = 2, line_size = 1, vert_size = 1, 
                     color_pos = palette_light()[[1]], 
                     color_neg = palette_light()[[2]]) {
    
    feature_expr <- enquo(target)
    feature_name <- quo_name(feature_expr)
    
    data_cor <- data %>%
        get_cor(!! feature_expr, fct_reorder = fct_reorder, fct_rev = fct_rev) %>%
        mutate(feature_name_text = round(!! feature_expr, lbl_precision)) %>%
        mutate(Correlation = case_when(
            (!! feature_expr) >= 0 ~ "Positive",
            TRUE                   ~ "Negative") %>% as.factor())
    
    g <- data_cor %>%
        ggplot(aes_string(x = feature_name, y = "feature", group = "feature")) +
        geom_point(aes(color = Correlation), size = size) +
        geom_segment(aes(xend = 0, yend = feature, color = Correlation), 
                     size = line_size) +
        geom_vline(xintercept = 0, color = palette_light()[[1]], size = vert_size) +
        expand_limits(x = c(-1, 1)) +
        theme_tq() +
        scale_color_manual(values = c(color_neg, color_pos)) 
    
    if (include_lbl) g <- g + geom_label(aes(label = feature_name_text), 
                                         hjust = lbl_position)
    
    return(g)
    
}


plot_data %>%
  select_if(is.numeric) %>%
  select(-SalePrice) %>%
  plot_cor(Log_Sale_Price,fct_reorder = T)
  

#linear fit on 43 variables
lm_fit <- lm(Log_Sale_Price ~., data = train_processed_model) 

summary(lm_fit)


#stepwise aic forward regression on 43 variables
lm_fw_aic <- ols_step_forward_aic(lm_fit)

lm_fw_aic

fd_df <- tibble(
  rank = c(seq(1,27,1)),
  predictor = lm_fw_aic$predictors, 
  adj_r2 = lm_fw_aic$arsq) 


#plot No. of Variables vs Adjust R2

fd_df %>%
  ggplot(aes(rank, adj_r2)) +
  geom_point() +
  geom_line() +
  labs(x = "Number of Variables", y = "Adjust R2") +
  scale_x_continuous(breaks = c(seq(1,27,1))) +
  theme_bw()


#response function for 27 variables selected from forward aic regression
jtools::summ(lm_fw_aic$model)

#QQplot
p1_qq <- ols_plot_resid_qq(lm_fw_aic$model)

#Histogram
p2_hist <- ols_plot_resid_hist(lm_fw_aic$model)

#combine those qq and histogram together
cowplot::plot_grid(p1_qq, p2_hist)

#residual vs fitted value
ols_plot_resid_fit(lm_fw_aic$model)

# scatter plot of actual log sale price vs predicted log sale price
tibble(
  actual = train_processed_model$Log_Sale_Price,
  predicted = lm_fw_aic$model$fitted.values
) %>%
  ggplot(aes(actual, predicted)) +
  geom_point() +
  geom_abline(intercept = 0, slope = 1, color = "red", size = 1) +
  labs(x = "actual log sale price", y = "predicted log sale price") +
  theme_bw()

cor(train_processed_model$Log_Sale_Price, 
    lm_fw_aic$model$fitted.values)

bias <- function(Y_hat, Y){
  mean(Y_hat - Y)
}

Max_Dev <- function(Y_hat, Y){
  max(abs(Y_hat - Y))
}

Mean_Abs_Dev <- function(Y_hat, Y){
  mean(abs(Y_hat - Y))
}

Mean_sq_err <- function(Y_hat , Y){
  mean((Y_hat - Y)^2)
} 

test_processed <- data_process(test_df, train = F, test = T)
test_processed_model <- bake(rec_obj, new_data = test_processed)

# predction on log sale price
predicted_value_log <- lm_fw_aic$model %>%
  predict(test_processed_model)

# prediction on sale price
predicted_value <- exp(predicted_value_log)



y_hat_test_full_model = exp(lm_fit %>%
  predict(test_processed_model))


y_hat_test = predicted_value
y_test = test_df$SalePrice

tibble(
  actual = y_hat_test,
  predicted = y_test
) %>%
  ggplot(aes(actual, predicted)) +
  geom_point() +
  geom_abline(intercept = 0, slope = 1, color = "red") +
  labs(x = "actual sale price", y = "predicted sale price") +
  theme_bw()

cor(y_hat_test, 
    y_test)

#test performance on full model 
tibble(
  Bias = bias(y_hat_test_full_model, y_test),
  Maximum_Deviation = Max_Dev(y_hat_test_full_model, y_test),
  Mean_Absolute_Deviation = Mean_Abs_Dev(y_hat_test_full_model, y_test),
  Mean_Square_Error = Mean_sq_err(y_hat_test_full_model, y_test)
) %>%
  gather(key = "measure", value = "value") %>%
  pander::pander()

#test performance on reduced model 
tibble(
  Bias = bias(y_hat_test, y_test),
  Maximum_Deviation = Max_Dev(y_hat_test, y_test),
  Mean_Absolute_Deviation = Mean_Abs_Dev(y_hat_test, y_test),
  Mean_Square_Error = Mean_sq_err(y_hat_test, y_test)
) %>%
  gather(key = "measure", value = "value") %>%
  pander::pander()

