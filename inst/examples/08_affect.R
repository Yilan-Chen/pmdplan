library(pmdplan)
data("affect", package = "pmdplan")
head(affect)
dim(affect)
# x1-x4: happy, excited, relaxed, satisfied.
# y1-y4: angry, anxious, depressed, sad.
# N_index identifies participants; time is measurement order.
# See ?pmd_forms and ?pmd_occasions for planned missingness examples.
# Data license: CC BY-NC 4.0; see ?affect for attribution.
