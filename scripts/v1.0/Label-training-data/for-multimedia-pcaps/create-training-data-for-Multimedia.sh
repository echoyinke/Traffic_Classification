# This script is meant for fetching multimedia flows from the trace file given.
# This script finally generates a csv file containing 4-tuple(SIP,DIP,SP,DP) along with 8 feature values for that flow. Each row in that csv represents a unique flow.

# As we use this script to fetch multimedia flows, and they are further used to train the classifier. The traces we took on different machines and we were only interested in all incoming packets. So we set filters to identify incoming packets. In our case, the client machines had following IPs.
client_ip34="172.16.1.34"
client_ip12="172.16.1.12"
client_ip13="172.16.1.13"

# Delete temporary files which are not needed,
# Here we have used *csv, *txt which will delete all txt and csv files, so be CAREFUL.
rm -rf *csv *.txt

# Here we want to run this script on all the trace files (pcap files) present in the current directory.
# keep all the training pcap files in the current folder before running this script.


# following loop, takes each pcap file one by one and on each pcap file it applies tshark command with filter as 'all packets which are outgoing from any of the mentioned IP addresses AND which have HTTP GET request AND the http request URI  contains any one of the mentioned multimedia file format'. 
# so all it does is that it finds all the packets having GET request going to web-servers and put their details (time, SIP, DIP, SP, DP etc) in a txt file named as pcapFileName-port.txt.
# for each pcap file, we have one txt file generated here

# Now this txt file is given to another script 'generate-list-of-port-with-GET-request.py' , which will create a filter string (and writes it in filter.txt file) that will be used again by tshark command to fetch all packets who belong to the port numbers mentioned in the txt file given as input


# we will move all the pcaps to the follwoing directory which do not have HTTP GET request for multimedia file.
mkdir -p pcaps_without_GET_request
echo "==================================="

for f in *.pcap
	do
				echo $f								# print on screen
				get_out=$f-port.txt					

	tshark -r $f  -R "((ip.src==$client_ip12 or ip.src==$client_ip13 or ip.src==$client_ip34) && http.request.method == "GET" ) &&  ( http.request.uri contains  mp4 ||  http.request.uri contains  .smil || http.request.uri contains  mp3 || http.request.uri contains  mkv || http.request.uri contains  avi || http.request.uri contains  3gp || http.request.uri contains  .webm || http.request.uri contains  .flv || http.request.uri contains  .vob || http.request.uri contains  .mov || http.request.uri contains  .wmv || http.request.uri contains  .rmvb || http.request.uri contains  .m4p || http.request.uri contains  .m4v || http.request.uri contains  .mpg || http.request.uri contains  .mpeg || http.request.uri contains  .3g2 || http.request.uri contains  .aa || http.request.uri contains  .aac || http.request.uri contains  .aax || http.request.uri contains  .act || http.request.uri contains  .aiff || http.request.uri contains  .amr || http.request.uri contains  .ape || http.request.uri contains  .au || http.request.uri contains  .awb || http.request.uri contains  .dct || http.request.uri contains  .dss || http.request.uri contains  .dvf || http.request.uri contains  .flac || http.request.uri contains  .gsm || http.request.uri contains  .m4a || http.request.uri contains  .m4b || http.request.uri contains  .mmf || http.request.uri contains  .mpc || http.request.uri contains  .ogg || http.request.uri contains  .oga || http.request.uri contains  .opus || http.request.uri contains  .ra || http.request.uri contains  .rm || http.request.uri contains  .raw || http.request.uri contains  .sln || http.request.uri contains  .tta || http.request.uri contains  .vox || http.request.uri contains  .wav || http.request.uri contains  .wma || http.request.uri contains  .wa || http.request.uri contains  .webm ) && !(http.request.uri contains  .png || http.request.uri contains  .jpg  )" -T fields -e frame.time_relative -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e ip.len -e tcp.flags.push -e tcp.window_size  -E separator='|' > $get_out # port.txt contains only packets with get  


				python generate-list-of-port-with-GET-request.py $get_out 			# This will create filter.txt , having filter string
				rm -rf  $get_out													# remove it, as not required any more
			
				fil=`cat filter.txt`												# now variable fil containts the content of filter.txt
				rm filter.txt														# remove it, as not required any more
				
				
			
				if [ -z "$fil" ]; then												# if the filter is empty, it means no packet with GET request and file format found
						echo "*****No GET request with desired file extension******" 
						echo $f
						mv $f pcaps_without_GET_request/ 
				else
						# it simply applies the filter on the pcap file and extracts the required packet header info in a txt file, named as pcapFileName.txt
						# Here, This $fil contains filters like "tcp.dstport == 47997 or tcp.dstport == 49146 or ...." , so all packets coming to these ports are put in $f.csv"
						# all these packets belong to multimedia

						tshark -r $f  -R "$fil" -T fields -e frame.time_relative -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e ip.len -e tcp.flags.push -e tcp.window_size -E separator='|' > $f.txt
						
				fi
	
done		
# for loop ends here

# Next 'create-header.py' will generate a csv file containing only one row .i.e. Header, that will be used when we merge all CSV files into one file
python create-header.py > aaa_Header.csv				# this filename must come first in alphabetical order, this is needed for successfully merging the csv files
														# that's why dummy aaa appended in the name, in the front.

# Now, we already have one txt file containing info abt multimedia packets, for each pcap file. Each of these txt file is given to another script 'create-csv-with-flow-features.py'
# which will create a csv file which contains 4 tuple (SIP,DIP,SP,DP) and values of 8 features. Each row represents a multimedia flow.
for f in *.txt
do
	python create-csv-with-flow-features.py $f 1000 > $f.csv    # 1st parameter : txt file ; 2nd parameter : threshold points (no. of packets after which classification need to be done)
	
done


# now we will manually find multimedia flow for the pcaps available in directory - pcaps_without_GET_request. For this we will call another script. For this we will copy relavent scripts from create-training-data-multimedia-with-NO-GET-request to  pcaps_without_GET_request.
cp create-training-data-multimedia-with-NO-GET-request/* pcaps_without_GET_request/      
cnt=0														
cnt=`ls pcaps_without_GET_request/*pcap |wc -l`					# cnt variable counts the number of pcaps with NO GET request
if [ $cnt -ne 0 ]; then											# if cnt not ZERO, then go in that directory and do processing					
	cd pcaps_without_GET_request
	bash create-training-data-no-GET-multimedia.sh
fi
cd ..  															# come out of pcaps_without_GET_request directory

rm -rf all-multimedia-flows.csv
cat *.csv pcaps_without_GET_request/all-multimedia-flows.csv > all-multimedia-flows.csv

# at this point of time, we have created 'all-multimedia-flows.csv' which contains all the multimedia flows along with their feature values.
# Now just put all temporary txt and csv file to a new directory txt-files and CSV-files respectively.
rm aaa_Header.csv				# not required, delete it
mkdir -p CSV-files				# create directory if not exist already
mkdir -p txt-files


mv *txt pcaps_without_GET_request/txt-files/*txt txt-files/
mv *csv pcaps_without_GET_request/CSV-files/*csv CSV-files/

mv CSV-files/all-multimedia-flows.csv .
