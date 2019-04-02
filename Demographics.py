# -*- coding: utf-8 -*-
"""
Created on Mon Apr  2 08:35:54 2018
GP Demographics results
@author: coxjil
"""

#import sample driver retention data
import pandas as pd
retention= "RetentionAccident.csv"
df= pd.read_csv(retention)
h = df.head(5)
print(h)
#drop unneeded columns
df= df.drop(columns=['phone', 'groupavgpay', 'CSA_month', 'Vio_month',
                     'sumlayover', 'avglayover', 'student_to_team_driver_days'])

#import GP data
GP1 = "cven_Upr00100.csv"
GP100 = pd.read_csv(GP1, low_memory=False)
#keep only the columns we want
GP100= GP100[['EMPLOYID', 'GENDER', 'ETHNORGN', 'MARITALSTATUS']]
GP100.head(5)

GP2 = "cven_Upr00111.csv"
GP111 = pd.read_csv(GP2)
#keep only the columns we want
GP111= GP111[['EMPLOYID', 'DEPENDENTSSN']]
GP111.head(5)

#multiple dependents for some employees
#sum over the partition by EMPLOYID and count the number of dependents
GP111 = GP111.groupby(by= ['EMPLOYID'])['DEPENDENTSSN'].count()
#reset the index
GP111 = GP111.reset_index()
#check that it did what we wanted
GP111.head(30)

# merge the two GP tables
GPtotal= pd.merge(GP100, GP111, how= 'left', on= 'EMPLOYID')
#rename column EMPLOYID to match retention sample
#df.rename(columns= {'old_columnname':'new_columnname'}, inplace=True)
GPtotal.rename(columns= {'EMPLOYID': 'mpp_id'}, inplace= True)

# merge driver retention sample data with the GP demographics data
#covert mpp_id to a string so the merge will work
GPtotal['mpp_id']= GPtotal['mpp_id'].astype(str)
df['mpp_id']= df['mpp_id'].astype(str)
Retention= pd.merge(df, GPtotal, how= 'left', on= 'mpp_id')

####################exploratory analyzis##########################
#deal with NAs
#replace missing values with 0 so they can be easily un/included
Retention['GENDER']= Retention['GENDER'].fillna(value=0)
Retention['ETHNORGN']= Retention['ETHNORGN'].fillna(value=0)
Retention['MARITALSTATUS'] = Retention['MARITALSTATUS'].fillna(value=0)
Retention['DEPENDENTSSN'] = Retention['DEPENDENTSSN'].fillna(value=0)

#exploratory tables
#look at GP differences 
# put names to factors
Retention['GENDER']= Retention['GENDER'].astype('category')
Retention['GENDER']= Retention['GENDER'].replace(0.0, 'UNKNOWN')
Retention['GENDER']= Retention['GENDER'].replace(1.0, 'MALE')
Retention['GENDER']= Retention['GENDER'].replace(2.0, 'FEMALE')
Retention['GENDER']= Retention['GENDER'].replace(3.0, 'UNKNOWN')

Retention['stayed']= Retention['stayed'].astype('category')
Retention['stayed']= Retention['stayed'].replace(0.0, 'Left')
Retention['stayed']= Retention['stayed'].replace(1.0, 'Stayed')
#gender
gender= pd.crosstab(index= Retention['stayed'], columns= Retention['GENDER'], margins=True) # by count
prop_gender= gender/gender.loc["All"] #by proportion by column

Retention['MARITALSTATUS']= Retention['MARITALSTATUS'].astype('category')
Retention['MARITALSTATUS']= Retention['MARITALSTATUS'].replace(0.0, 'UNKNOWN')
Retention['MARITALSTATUS']= Retention['MARITALSTATUS'].replace(1.0, 'MARRIED')
Retention['MARITALSTATUS']= Retention['MARITALSTATUS'].replace(2.0, 'SINGLE')
Retention['MARITALSTATUS']= Retention['MARITALSTATUS'].replace(3.0, 'UNKNOWN')

Retention['ETHNORGN']= Retention['ETHNORGN'].astype('category')
Retention['ETHNORGN']= Retention['ETHNORGN'].replace(1.0, 'WHITE')
Retention['ETHNORGN']= Retention['ETHNORGN'].replace(2.0, 'AM. INDIAN')
Retention['ETHNORGN']= Retention['ETHNORGN'].replace(3.0, 'BLACK')
Retention['ETHNORGN']= Retention['ETHNORGN'].replace(4.0, 'ASIAN')
Retention['ETHNORGN']= Retention['ETHNORGN'].replace(5.0, 'HISPANIC')
Retention['ETHNORGN']= Retention['ETHNORGN'].replace(6.0, '2+ Races')
Retention['ETHNORGN']= Retention['ETHNORGN'].replace(7.0, 'UNKNOWN')
Retention['ETHNORGN']= Retention['ETHNORGN'].replace(8.0, 'Pacific Islander')
Retention['ETHNORGN']= Retention['ETHNORGN'].replace(0.0, 'UNKNOWN')

#marital status
married= pd.crosstab(index= Retention['stayed'], columns= Retention['MARITALSTATUS'], margins= True)
prop_married= married/married.loc["All"]

#Ethnicity
ethnicity= pd.crosstab(index= Retention['stayed'], columns=Retention['ETHNORGN'], margins= True)
prop_ethnicity= ethnicity/ethnicity.loc["All"]

#Dependents binary
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].astype('category')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(1, 'none')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(2, '1')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(3, '2+')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(0, 'UNKNOWN')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(4, '2+')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(5, '2+')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(6, '2+')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(7, '2+')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(8, '2+')
Retention['DEPENDENTSSN']= Retention['DEPENDENTSSN'].replace(10, '2+')
#replace values with class labels
#iris.species= np.where(iris.species == 0.0, 'setosa', 
#                       np.where(iris.species==1.0, 'versicolor', 'virginica'))

# find if anything was missed
Retention['DEPENDENTSSN'].unique()
#higher dimensional tables
mar_deps= pd.crosstab(index= Retention['stayed'], columns=[Retention['MARITALSTATUS'], 
                      Retention['DEPENDENTSSN']],
                      margins= True)
prop_mar_deps= mar_deps/mar_deps.loc["All"]

#more details
Active_driving_days= pd.pivot_table(Retention, values= ['active_driving_day_per'],
                                    index= ['stayed', 'DEPENDENTSSN'],
                                    columns= ['MARITALSTATUS'])

dayshome= pd.pivot_table(Retention, values= ['dayshome'],
                                    index= ['stayed', 'DEPENDENTSSN'],
                                    columns= ['MARITALSTATUS'])
Active_days = pd.pivot_table(Retention, values= ['active_driving_day_count'],
                                    index= ['stayed', 'DEPENDENTSSN'],
                                    columns= ['MARITALSTATUS'])
Retention.describe()
#compare standard metrics between stayed and left
Stayed=Retention[Retention['stayed'] == 'Stayed']
Left= Retention[Retention['stayed'] == 'Left']
S_desc= Stayed.describe()
L_desc= Left.describe()

#graphs
import matplotlib.pyplot as plt
hist= Retention.hist()
plt.suptitle("Histrogram", fontsize=16)
plt.show() 

Retention.groupby(by= "stayed").mean()
Retention.groupby(by= "stayed").mean().plot(kind= "bar")

#look at correlation
corr= Retention.corr()
print(corr)

################################## modeling############################




