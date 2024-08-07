# Cargar paquetes necesarios
install.packages("pacman")
library(pacman)
packages <- c("tidyverse", "janitor", "readxl", "rstudioapi", "openxlsx",
              "dplyr", "corrplot", "MVN", "factoextra", "ggplot2", "caret",
              "psych")
pacman::p_load(char = packages, character.only = TRUE)

# Configurar el directorio de trabajo
setwd(dirname(getActiveDocumentContext()$path))

# Cargar y limpiar datos
datos_orig <- as.data.frame(read_excel("muestra_heart.xlsx")) %>%
  clean_names()

datos <- datos_orig %>%
  select(-death_event, -sex)

## 1. ANÁLISIS EXPLORATORIO DE LOS DATOS ######################################

# Mostrar la estructura de los datos
str(datos)

# Mostrar los primeros 10 elementos
head(datos, 10)

# Estadísticas descriptivas
summary(datos)

#Histogramas

hist(datos$age,
     main = "Histograma de Edad",
     xlab = "Edad",
     ylab = "Frecuencia",
     col = "royalblue3",
     ylim = c(0, 50),
     border = "black")

hist(datos$ejection_fraction,
     main = "Histograma de Eyección",
     xlab = "Porcentaje de Eyección",
     ylab = "Frecuencia",
     col = "lightblue3",
     ylim = c(0, 50),
     border = "black")

hist_data <- hist(datos$platelets,
                  main = "Histograma de Plaquetas",
                  xlab = "Plaquetas (kiloplaquetas/ml)",
                  ylab = "Frecuencia",
                  col = "lightblue4",
                  border = "black",
                  ylim = c(0, 50),
                  xaxt = "n")
xlim <- range(hist_data$breaks)
axis(1, at = pretty(xlim), labels = format(pretty(xlim), scientific = FALSE))


hist(datos$serum_sodium,
     main = "Histograma de Sodio Sérico",
     xlab = "Sodio Sérico mE/L",
     ylab = "Frecuencia",
     col = "cyan3",
     ylim = c(0, 50),
     border = "black")

hist(datos$serum_creatinine,
     main = "Histograma de Suero de Creatinina",
     xlab = "Suero de Creatinina mE/L",
     ylab = "Frecuencia",
     col = "lightslateblue",
     ylim = c(0, 50),
     border = "black")


#Graficas de pie


pie(table(datos_orig$sex),
    labels = paste(c("Mujeres", "Hombres"), 
                   "(", round(prop.table(table(datos_orig$sex)) * 100, 1), "%)"),
    main = "Distribución por Sexo",
    col = c("lightblue", "lightcoral"))

pie(table(datos_orig$death_event),
    labels = paste(c("No Fallecido", "Fallecido"), 
                   "(", round(prop.table(table(datos_orig$death_event)) * 100, 1), "%)"),
    main = "Distribución por Caso",
    col = c("green4", "navyblue"))



# Calcular y graficar matriz de correlación
correlaciones <- cor(datos)
corrplot(correlaciones,
         method = "color",
         addCoef.col = "black",
         tl.col = "black",
         tl.srt = 45,
         tl.cex = 0.8,
         number.cex = 0.7,
         col = colorRampPalette(c("white", "#B22222"))(200))

# Vector de medias y matriz de varianza y covarianza
colMeans(datos, na.rm = TRUE) %>%
  matrix(ncol = 1)

a<-cov(datos, use = "complete.obs")

## 2. PRUEBAS DE BONDAD DE AJUSTE #############################################

caracteristicas <- datos %>% select(-serum_creatinine)

# Realizar las pruebas de normalidad multivariada
mvn(caracteristicas, mvnTest = "hz")

## 3. PRUEBAS COMPARATIVAS ####################################################

## Independencia

#H0: Independencia para las variables
#Ha: Las variables no son independientes


p <- ncol(caracteristicas)
n <- nrow(caracteristicas)
R <- cor(caracteristicas)

# Calcular estadístico de prueba
-2 * (1 - ((2 * p + 11) / (6 * n))) * log(det(R)**(50 / 2)) #EP = 8.77

# Calcular valor crítico
qchisq(1 - 0.05, p * (p - 1) / 2) # RR = 12.59

# Rechazo H0 si EP = 8.77 > RR = 12.59

# No rechazo H0, las variables son independientes

# Las variables de edad, ejection_fraction, platelets y serum_sodium
# son independientes 


## Prueba de medias

#H0: Las medias para edad = 60, ejection = 60, platelets =275000,
#    serum_sodium =140
#H0: Las medias son distintas a las planteadas

# Definir medias hipotéticas
mu_hipotesis <- c(60, 60, 275000, 140) %>%
  matrix(ncol = 1)

# Calcular medias observadas
x_barra <- colMeans(datos %>% select(age, ejection_fraction, platelets,
                                     serum_sodium)) %>%
  matrix(ncol = 1)

# Calcular matriz de covarianza y su inversa
covs <- cov(caracteristicas)
inv_cov <- solve(cov(caracteristicas))

# Calcular estadístico T²
t2 <- n * t(x_barra - mu_hipotesis) %*% inv_cov %*% (x_barra - mu_hipotesis)

# Calcular valor p
1 - pf((n - p) * t2 / ((n - 1) * p), p, n - p)

# Rechazo H0 si p-valor = 6.7 x 10^-16 < alfa = 0.05
# Rechazo H0
# Las medias son distintas a las planteadas

## Intervalos de confianza (I. C.)

# Calcular factor auxiliar para los intervalos de confianza
aux <- qf(1 - 0.05, p, n - p) * p * (n - 1) / (n * (n - p))

# Calcular e imprimir intervalos de confianza
ic <- function(media, varianza) {
  sqrt_aux <- sqrt(aux * varianza)
  c(media - sqrt_aux, media + sqrt_aux)
}

ic_values <- sapply(1:p, function(i) ic(x_barra[i], covs[i, i]))
rownames(ic_values) <- c("Límite inferior", "Límite superior")
colnames(ic_values) <- c("age", "ejection_fraction", "platelets",
                         "serum_sodium")


#Diferencia vector de medias MUERTE

#H0: El vector de medias no difiere entre pacientes que murieron y no
#Ha: El vector de medias difiere entre pacientes que murieron y no

# Filtrar datos de pacientes muertos y vivos
dead <- datos_orig %>% filter(death_event == 1) %>% select(-death_event,-sex,-serum_creatinine)
alive <- datos_orig %>% filter(death_event == 0) %>% select(-death_event,-sex,-serum_creatinine)

# Calcular vectores de medias y matrices de covarianza
media_d <- colMeans(dead) %>% matrix(ncol = 1)
media_a <- colMeans(alive) %>% matrix(ncol = 1)
vd <- cov(dead)
va <- cov(alive)

# Tamaño de las muestras
n1 <- nrow(dead)
n2 <- nrow(alive)

# Calcular matriz de covarianza ponderada y ajustada
sp <- ((n1 - 1) * vd + (n2 - 1) * va) / (n1 + n2 - 2)
sp_esc <- sp * (1 / n1 + 1 / n2)

# Calcular estadístico T²
delta <- media_d - media_a
t(delta) %*% solve(sp_esc) %*% delta
# EP = 6.69

# Calcular valor crítico F y región de rechazo
valor_f <- qf(1 - 0.05, p, n1 + n2 - p - 1)
region_rechazo <- valor_f * p * (n1 + n2 - 2) / (n1 + n2 - p - 1) # RR = 11.00

# Rechazo H0 si t² > región de rechazo
# En este caso: 6.69 < 11.00, por lo que no se rechaza H0
# El vector de medias no difiere entre pacientes que murieron y no

# Calcular intervalos de confianza
sqrt_aux <- sqrt(region_rechazo * diag(sp_esc))
lim_inf <- media_d - media_a - sqrt_aux
lim_sup <- media_d - media_a + sqrt_aux

data.frame(
  Inferior = lim_inf,
  Media = media_d - media_a,
  Superior = lim_sup
)

#Diferencia vector de medias SEXO

#H0: El vector de medias no difiere entre pacientes masculinos y femeninos
#Ha: El vector de medias difiere entre pacientes masculinos y femeninos

# Filtrar datos de pacientes masculinos y femeninos
masc <- datos_orig %>% filter(sex == 1) %>% select(-death_event, -sex, -serum_creatinine)
fem <- datos_orig %>% filter(sex == 0) %>% select(-death_event, -sex, -serum_creatinine)

# Calcular vectores de medias y matrices de covarianza
media_m <- colMeans(masc) %>% matrix(ncol = 1)
media_f <- colMeans(fem) %>% matrix(ncol = 1)
vm <- cov(masc)
vf <- cov(fem)

# Tamaño de las muestras
n1 <- nrow(masc)
n2 <- nrow(fem)

# Calcular matriz de covarianza ponderada y ajustada
sp <- ((n1 - 1) * vm + (n2 - 1) * vf) / (n1 + n2 - 2)
sp_esc <- sp * (1 / n1 + 1 / n2)

# Calcular estadístico T²
delta <- media_m - media_f
t(delta) %*% solve(sp_esc) %*% delta # EP = 6.57

# Calcular valor crítico F y región de rechazo
valor_f <- qf(1 - 0.05, p, n1 + n2 - p - 1)
region_rechazo <- valor_f * p * (n1 + n2 - 2) / (n1 + n2 - p - 1) # RR = 11.00

# Rechazo H0 si t² > región de rechazo
# En este caso: 6.57 < 11.00, por lo que no se rechaza H0
# El vector de medias no difiere entre pacientes masculinos y femeninos

# Calcular intervalos de confianza
sqrt_aux <- sqrt(region_rechazo * diag(sp_esc))
lim_inf <- delta - sqrt_aux
lim_sup <- delta + sqrt_aux

data.frame(
  Inferior = lim_inf,
  Media = delta,
  Superior = lim_sup
)


## 4. TÉCNICA MULTIVARIADA ####################################################

# Normalización de datos
cp <- scale(caracteristicas)

# Mostrar resumen de los datos normalizados
summary(cp)

# Realizar PCA
pca_result <- prcomp(cp)

# Resumen del PCA
summary(pca_result)

# Gráfica de codo
fviz_eig(pca_result, addlabels = TRUE)

# Según el criterio del codo, se eligen 3 componentes
num_components <- 3

# Mostrar los coeficientes de la transformación
pca_result$rotation[, 1:num_components]

# Conjunto de datos transformado al nuevo espacio
pca_result$x[, 1:num_components]

# TÉCNICA MULTIVARIADA: ANÁLISIS DISCRIMINANTE

# Filtrar datos para el análisis discriminante
datos_lda <- datos_orig %>%
  select(-sex) %>%
  mutate(death_event = as.factor(death_event))

# Dividir datos en conjunto de entrenamiento y prueba
set.seed(123)
trainIndex <- createDataPartition(datos_lda$death_event, p = 0.8, list = FALSE)
trainData <- datos_lda[trainIndex, ]
write.csv(trainData, file = "train_data.csv", row.names = FALSE)

testData <- datos_lda[-trainIndex, ]
write.csv(testData, file = "test_data.csv", row.names = FALSE)

# Separar datos por clase
dead <- trainData %>% filter(death_event == 1) %>% select(-death_event)
alive <- trainData %>% filter(death_event == 0) %>% select(-death_event)

# Calcular medias de las clases
media_d <- colMeans(dead) %>% matrix(ncol = 1)
media_a <- colMeans(alive) %>% matrix(ncol = 1)

# Calcular matrices de varianza-covarianza
cov_d <- cov(dead)
cov_a <- cov(alive)

# Calcular matriz de covarianza agrupada
n1 <- nrow(dead)
n2 <- nrow(alive)
sp <- ((n1 - 1) * cov_d + (n2 - 1) * cov_a) / (n1 + n2 - 2)

# Calcular coeficientes de discriminación
inv_sp <- solve(sp)
delta <- media_d - media_a
w <- t(delta) %*% inv_sp
b <- -0.5 * (t(media_d) %*% inv_sp %*% media_d - t(media_a) %*% inv_sp %*% media_a)

# Función discriminante
discriminante <- function(x, w, b) {
  w %*% x + b
}

# Realizar predicciones en el conjunto de prueba
X_test <- as.matrix(testData %>% select(-death_event))
y_test <- testData$death_event

# Aplicar función discriminante
predictions <- apply(X_test, 1, function(row) {
  ifelse(discriminante(as.matrix(row), w, b) > 0, 1, 0)
})

# Crear matriz de confusión
confusionMatrix(as.factor(predictions), y_test)

# Normalizar datos para PCA
trainData_scaled <- trainData %>%
  select(-death_event) %>%
  scale()

# Realizar PCA
pca_result <- prcomp(trainData_scaled, center = TRUE, scale. = TRUE)

# Crear un data frame con las componentes principales
pca_data <- data.frame(pca_result$x, death_event = trainData$death_event)


# Graficar los resultados del PCA
ggplot(pca_data, aes(x = PC1, y = PC2, color = death_event)) +
  geom_point(alpha = 0.8, size = 3) +
  scale_color_manual(values = c("0" = "darkblue", "1" = "darkred")) +
  labs(title = "Análisis de Componentes Principales (PCA)",
       x = "Componente Principal 1 (PC1)", y = "Componente Principal 2 (PC2)",
       color = "Estado del Paciente") +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    axis.title = element_text(size = 14),
    legend.title = element_text(size = 12),
    legend.text = element_text(size = 10)
  )



# TÉCNICA MULTIVARIADA: ANÁLISIS DE FACTORES

# Graficar el criterio del codo
calcular_varianza_explicada <- function(datos, max_factors) {
  varianza_explicada <- numeric(max_factors)
  
  for (n in 1:max_factors) {
    fa_result <- fa(datos, nfactors = n, rotate = "varimax")
    varianza_explicada[n] <- sum(fa_result$values) / sum(eigen(cor(datos))$values)
  }
  
  return(varianza_explicada)
}

# Número máximo de factores a considerar
max_factors <- 4

# Calcular la varianza explicada
varianza_explicada <- calcular_varianza_explicada(cp, max_factors)

# Graficar el criterio del codo
plot(1:max_factors, varianza_explicada, type = "b", pch = 19,
     xlab = "Número de factores", ylab = "Varianza explicada",
     main = "Criterio del codo para selección de factores")

# Realizar el análisis de 2 factores (seleccionados por el criterio del codo)
fa_result <- fa(cp, nfactors = 2, rotate = "varimax")

