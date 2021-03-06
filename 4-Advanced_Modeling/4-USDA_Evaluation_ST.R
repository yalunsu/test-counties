# Robert Dinterman

print(paste0("Started 4-USDA_Evaluation_ST at ", Sys.time()))

# ---- Start --------------------------------------------------------------

library(dplyr)
library(gstat)
library(sp)
library(spacetime)

# suppressMessages(library(tidyr))

# Create a directory for the data
localDir <- "4-Advanced_Modeling/USDA_Evaluation"
if (!file.exists(localDir)) dir.create(localDir)

load("1-Organization/USDA_Evaluation/Final.Rda")
data$iloans <- 1*(data$loans > 0)
data$ipilot <- 1*(data$ploans > 0)
data$icur   <- 1*(data$biploans1234 > 0)
data %>%
  group_by(zip, year, STATE, ruc03, ruc, SUMBLKPOP) %>%
  dplyr::select(Prov_num, emp:emp_, Pop_IRS, HHINC_IRS_R, HHWAGE_IRS_R,
                logINC, ap_R, qp1_R, POV_ALL_P, roughness, slope, tri, AREA,
                Prov_alt, loans, ploans, biploans1234, iloans, ipilot, icur,
                long, lat) %>%
  summarise_each(funs(mean)) -> pdata

pdata$Prov_alt <- round(pdata$Prov_alt)
pdata$Prov_num <- round(pdata$Prov_num)
# sdata <- STFDF(SpatialPoints(cbind(unique(pdata$long), unique(pdata$lat))),
#                as.Date(unique(as.character(pdata$year)), "%Y"),
#                data.frame(pdata))

#STdata <- filter(pdata, STATE == "TX")
STdata <- pdata

STsp   <- SpatialPoints(cbind(unique(STdata$long), unique(STdata$lat)))
raster::projection(STsp) <- CRS("+init=epsg:4326")
STsp   <- spTransform(STsp,CRS("+init=epsg:3395"))

STtime <- as.Date(unique(as.character(STdata$year)), "%Y")

STst   <- STFDF(STsp, STtime, data.frame(STdata))

STpool <- SpatialPointsDataFrame(cbind(STdata$long, STdata$lat),
                                 data.frame(STdata))
raster::projection(STpool) <- CRS("+init=epsg:4326")
STpool <- spTransform(STpool,CRS("+init=epsg:3395"))

j6 <- list()
for (i in unique(STpool$year)){
  SThuh <- subset(STpool, year == i)
  j5    <- variogram(round(Prov_num) ~ log(est) + log(Pop_IRS) + logINC +
                       tri + ruc, SThuh, cutoff = 5000)
  
  j6[[paste(i)]] <- list(j5)
  
  print(plot(j5, main = paste(i)))#, ylim = c(0, 1)))
}


system.time(
  j7 <- variogram(round(Prov_num) ~ log(est) + log(Pop_IRS) + logINC +
                  tri + ruc + factor(year), STpool, cutoff = 5000)
)

plot(j7, main = "Pooled Variogram")

# http://r-video-tutorial.blogspot.com/2015/08/
#  spatio-temporal-kriging-in-r.html

# ---- VariogramST --------------------------------------------------------

system.time(
  j5 <- variogramST(Prov_num ~ log(est) + log(Pop_IRS) + logINC +
                  tri + ruc + factor(year), STst, assumeRegular = T,
                  cutoff = 5000)
)

plot(j5, map = F)
plot(j5)
plot(j5, wireframe = T)

# ---- Spatial ------------------------------------------------------------
# http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0082142

# This was done by using the functions “corSpatial” and “glmmPQL” available in
#  the packages “nlme” and “MASS” in R, respectively. The so-called penalized
#  quasi-likelihood (PQL) allow for fitting the variance-covariance-matrix to
#  the data, thus resulting in a spatial GLMM. 
# 
# library(MASS)
# library(nlme)
# pdata$rprov <- round(pdata$Prov_num)
# system.time(
#   sppois <- glmmPQL(rprov ~ iloans + log(est) + log(Pop_IRS) + logINC +
#                       tri + ruc,# + factor(year),
#                     random = ~ 1 | factor(year),
#                     family = poisson, data = filter(pdata, STATE == "MN"),
#                     correlation = corSpatial(form = ~ long + lat | factor(year),
#                                              type = "exponential",
#                                              metric = "euclidean"))
# )
# 
# separable <- vgmST("separable", space = vgm(-20,"Sph", 5000, 1),
#                    time = vgm(1,"Sph", 5000, 1), sill=0.5)
# plot(j5, separable, map = F)
# separable_Vgm <- fit.StVariogram(j5, separable, fit.method=0)
# attr(separable_Vgm,"MSE")
# 
# pars.l <- c(sill.s = 0, range.s = 10, nugget.s = 0,sill.t = 0, range.t = 1,
#             nugget.t = 0, sill.st = 0, range.st = 10, nugget.st = 0, anis = 0)
# pars.u <- c(sill.s = 200, range.s = 1000, nugget.s = 100, sill.t = 200,
#             range.t = 60, nugget.t = 100,sill.st = 200, range.st = 1000,
#             nugget.st = 100, anis = 700) 
# 
# separable_Vgm <- fit.StVariogram(j5, separable, fit.method = 11,
#                                  method = "L-BFGS-B", stAni = 5,
#                                  lower = pars.l, upper = pars.u)
# attr(separable_Vgm, "MSE")