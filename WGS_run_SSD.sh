##################
#
# Select Reads
#
##################
SIMPLIFIED_READ_FOLDER=SSD_WGS_SIMPLIFIED_READ
SOURCE_READ=../../Dataset/ERR194158_1.fastq
SIMPLIFIED_FILENAME=ERR194158_1_r.fastq
SIMPLIFIED_NUM=10000
#350x1000

mkdir $SIMPLIFIED_READ_FOLDER
python3 simplifier.py $SOURCE_READ ./$SIMPLIFIED_READ_FOLDER/$SIMPLIFIED_FILENAME $SIMPLIFIED_NUM

##################
#
# Quality Control
#
##################
QUALIFIED_FILENAME=ERR194158_1_rq.fastq
fastp -i ./$SIMPLIFIED_READ_FOLDER/$SIMPLIFIED_FILENAME  -o ./$SIMPLIFIED_READ_FOLDER/$QUALIFIED_FILENAME -l 100 --trim_poly_g

################################
#
# Move to data-set and remove
#
################################
READ_FOLDER=SSD_WGS_ERR194158_DATASET

mkdir $READ_FOLDER
mv ./$SIMPLIFIED_READ_FOLDER/$QUALIFIED_FILENAME ./$READ_FOLDER/$QUALIFIED_FILENAME
cd $READ_FOLDER
gzip $QUALIFIED_FILENAME
cd ..


#####################
#
# Cluster
#
#####################
CLUSTER_DIR=SSD_WGS_ERR194158_CLUSTER
mkdir $CLUSTER_DIR
./build/cluster-preprocessing/cluster 12 $CLUSTER_DIR $READ_FOLDER 0


####################
#
# Merge multiple runs
#
####################
./build/cluster-preprocessing/merge_runs-hbm 12 $CLUSTER_DIR 2 2 0
./build/cluster-preprocessing/merge_runs-ims 12 $CLUSTER_DIR 2 2 0

##################
#
# Reference genome index generation
#
##################
ORIGINAL_REF_IDX_PATH=SSD_WGS_ORIGINAL_REF_IDX
POST_RESULT=GRCh38.p12.genome.mmi
REFERENCE_FA=../../Dataset/GRCh38.p12.genome.fa
mkdir $ORIGINAL_REF_IDX_PATH
./build/minimap2-idx/gen-original-idx $REFERENCE_FA ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT
#OUTLIER_RESULT=ERR194158.out.result_TMP
#./build/minimap2-idx/gen-original-idx ./$CLUSTER_DIR/postprocess/outlier.fastq ./$ORIGINAL_REF_IDX_PATH/$OUTLIER_RESULT
#./build/minimap2-idx/gen-original-idx ./$CLUSTER_DIR/postprocess/postprocess.fastq ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT
################
#
# minimap2 performance reproduce
#
################
#./minimap2/minimap2 -t 12 -ax sr --frag=no ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT ./$CLUSTER_DIR/postprocess/postprocess.fastq >minimap_out_TMP

#################
#
#IMS system performance
#
#################
mkdir SSD_LOG
./build/host-mapping/IMS-read-centric-mlv 1 ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT 0 ./$CLUSTER_DIR/postprocess/ 1000 0 1 #>SSD_LOG/IMS_0
#./build/host-mapping/IMS-read-centric-mlv 1 ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT 1 ./$CLUSTER_DIR/postprocess/ 1000 0 1 >SSD_LOG/IMS_1
#################
#
# HBM system performance
#
#################
OUPUT_BIN_VECTOR_PATH=SSD_WGS_OUPUT_BIN_VECTOR
BIN_VECTOR=bin_vector
mkdir $OUPUT_BIN_VECTOR_PATH
#生成 bin vector index
./build/host-mapping/gen-grim-filter-idx ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT ./$OUPUT_BIN_VECTOR_PATH/$BIN_VECTOR
#q-gram filtering 在 CPU 做 (ref-centric)：
#./build/host-mapping/HBM-ref-centric-online 1 ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT ./$OUPUT_BIN_VECTOR_PATH/$BIN_VECTOR 3 ./$CLUSTER_DIR/postprocess/postprocess.fastq 1000
#q-gram filtering 用 HBM 做 (ref-centric)（會先 precalculate 計算結果，online 直接把結果 load 上來）：
#./build/host-mapping/HBM-ref-centric 1 ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT ./$OUPUT_BIN_VECTOR_PATH/$BIN_VECTOR 0 ./$CLUSTER_DIR/postprocess/postprocess.fastq 1000 0 0 1 >_LOG/IMS_1
#q-gram filtering 用 HBM 做 (read-centric)（會先 precalculate 計算結果，online 直接把結果 load 上來）：
#./build/host-mapping/HBM-read-centric 1  ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT 3 ./$CLUSTER_DIR/postprocess/ 1000 0 1 1
#################
#
# PIM Simlation
#
#################

PIM_SIM_OUTPUT_PATH=SSD_WGS_PIM_SIM_OUTPUT
mkdir $PIM_SIM_OUTPUT_PATH
PIM_SIM_OUTPUT_FILENAME=data_placement.json
SIM_CONFIG=./PIM-Sim/simplessd-standalone/config/2400-40us-8c-4d-4p-4K/11-c95.cfg
SSD_CONFIG=./PIM-Sim/simplessd-standalone/simplessd/config/2400-20us-8c-4d-4p-4K.cfg
mkdir SSD_LOG
LOG_DIR=SSD_LOG

python3 scripts/data_placement.py --postprocess_dir ./$CLUSTER_DIR/postprocess/ --output_path $PIM_SIM_OUTPUT_PATH/$PIM_SIM_OUTPUT_FILENAME
./build/PIM-Sim/simplessd-standalone/simplessd-standalone $SIM_CONFIG $SSD_CONFIG $LOG_DIR
################
#  DRAM SIM
################
DRAMSIM3_OUTPUT_PATH=SSD_WGS_DRAMSIM3_OUTPUT_PATH
DRAMSIM3_CONFIG_FILENAME=HBM2_GRIM-Filter.ini
cp ../../../PIM-Sim/GRIM-ref-centric/DRAMsim3/configs/$DRAMSIM3_CONFIG_FILENAME $DRAMSIM3_CONFIG_FILENAME

mkdir $DRAMSIM3_OUTPUT_PATH
./HBM-simulation 1 ../../../$ORIGINAL_REF_IDX_PATH/$POST_RESULT ../../../$OUPUT_BIN_VECTOR_PATH/$BIN_VECTOR ../../../$SIMPLIFIED_READ_FOLDER/$SIMPLIFIED_FILENAME $DRAMSIM3_CONFIG_FILENAME $DRAMSIM3_OUTPUT_PATH 1000


################
#
# Compare SAM Result
#
################
./sam_quality.py output_noq.sam output_q1.sam

./sam_quality.py read_TF100_re.output.sam read_TF3_re.output.sam


# temp
# ./build/host-mapping/IMS-read-centric-mlv 1 ./$ORIGINAL_REF_IDX_PATH/$POST_RESULT 0 ./$CLUSTER_DIR/postprocess/ 1000 0 1 