#!/bin/bash
HOST_A='10.10.10.138'               #Keystone host to gen token, create project. (Ha Noi)
HOST_B='10.10.10.139'               #Keystone host to check project. (Ho Chi Minh)
result=/root/project/result.txt       #Ket qua kiem tra lan luot.
ketqua=/root/project/ketqua.txt     #Ket qua trung gian de tinh trung binh.
trungbinh=/root/project/trungbinh.txt #Ket qua trung binh
list_project=/root/project/project.txt      #Ten cac project da duoc tao, kiem tra tren site Ho Chi Minh.
name_project=linh                                 #Ten project se duoc tao.
time_check_a_token=7200       #Total time to validate a token in sec
time_sleep=1                   #Time sleep between each validation in sec
username=admin             #user for gen token
password=Welcome123   #password for gen token
domain=default               #domain for gen token
project=admin                 #project for gen token
count_project=5                     #1 token tao 5 project
count_gen_token=3           #Tao bao nhieu token trong 1 lan chay?
######
###count
count_token_failed=0        #so lan tao token that bai
count_token_success=0       #so lan tao token thanh cong
count_token=0                      #so lan tao token
count_create=0                      #so lan tao project
count_create_failed=0           #so lan tao project  that bai (Ha Noi)
count_create_success=0          #so lan tao project thanh cong (Ha Noi)
count_check_success=0           #so lan kiem tra project thanh cong (Ho Chi Minh)
count_check_failed=0               #so lan kiem tra project that bai tren (Ho Chi Minh)
s_count_create_success=0        #Tong so lan tao project thanh cong (nhieu lan chay )
s_count_check_success=0         #Tong so lan kiem tra project thanh cong (tren nhieu lan chay)
s_count_create=0                      #Tong so lan tao project (tren nhieu lan chay)
#######
gen_token(){
    echo ----------------------------------------------------------------------------------------- | tee -a $result
    start=`date +%s`
    token=`python /root/project/check_keystone_v3.py --username $username --password $password --domain $domain --project $project --auth_url http://$HOST_A:35357/v3`
    ((count_token++))
    if [ $token == "" ]
    then
        echo -e `date` "\t" 0 "\t\t\t" | tee -a $result
        ((count_token_failed++))
        gen_token
    else
        echo -e `date` "\t" 1 "\t\t\t" | tee -a $result
        ((count_token_success++))
        get_domainid
        create_project
    fi
}

get_domainid(){
    domain_id=`python /root/project/get_domain.py --token $token --auth_url http://$HOST_A:35357/v3`
}
get_project(){
    python /root/project/get_project.py --token $token --auth_url http://$HOST_B:35357/v3 | tee $list_project
}

create_project(){
for i in `seq 1 $count_project`;
do
    for host in $HOST_B; do
            end=`date +%s`
            if [[ $((end-start)) -le $time_check_a_token ]]
            then
                ####create project on HaNoi
                ((count_create++))
                python /root/project/create_project.py --token $token --auth_url http://$HOST_A:35357/v3 --domain_id $domain_id --name_project $name_project$count_create
                if [ $? -eq 2 ]
                then
                    echo -e `date` "\t"  "\t\t\t\t" 0 | tee -a $result
                    ((count_create_failed++))
                else
                    echo -e `date` "\t"  "\t\t\t\t" 1 | tee -a $result
                    ((count_create_success++))
                fi
                ####check project on HoChiMinh
                get_project
                if grep -Fxq "$name_project$count_create" $list_project
                then
                    echo -e `date` "\t"  "\t\t\t\t\t\t" 1 | tee -a $result
                    ((count_check_success++))
                else
                    echo -e `date` "\t"  "\t\t\t\t\t\t" 0 | tee -a $result
                    ((count_check_failed++))
                fi
                ####
            fi
    done
    sleep $time_sleep
done
}
echo ----------------------------------------------------------------------------------------- | tee -a $result
echo -e Thoi Gian "\t\t\t" Tao token thanh cong "\t" Tao project HaNoi "\t" Check project Ho Chi Minh | tee -a $result
while [[ $count_token -lt $count_gen_token ]]; do
    gen_token
done
echo -----------------------------------------------------------------------------------------
echo -e `date` "|" $count_create_success "|" $count_check_success "|" $count_create | tee -a $ketqua
####Tinh ket qua trung binh 
if [[ -f "$ketqua" ]]
then
    while IFS='|' read -r ngaygio count_create_success_2 count_check_success_2 count_create_2
    do
        ((s_count_create_success+=$count_create_success_2))
        ((s_count_check_success+=$count_check_success_2))
        ((s_count_create+=$count_create_2))

    done <"$ketqua"
fi
tb1=$(echo "scale=2;$s_count_create_success / $s_count_create * 100" | bc)
tb2=$(echo "scale=2;$s_count_check_success / $s_count_create * 100" | bc)
echo -e HaNoi: $tb1%  "\t" HoChiMinh: $tb2% | tee $trungbinh