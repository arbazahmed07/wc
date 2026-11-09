
#!/bin/bash

echo "Starting Hadoop services..."
start-dfs.sh
start-yarn.sh

echo "Creating project directory..."
mkdir -p ~/mapreduce/classes
cd ~/mapreduce || exit

echo "Creating MostFrequentWord.java..."
cat > MostFrequentWord.java << "EOF"
import java.io.IOException;
import java.util.StringTokenizer;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.*;
import org.apache.hadoop.mapreduce.*;
import org.apache.hadoop.mapreduce.lib.input.*;
import org.apache.hadoop.mapreduce.lib.output.*;

public class MostFrequentWord {

    public static class TokenizerMapper
        extends Mapper<Object, Text, Text, IntWritable> {

        private final static IntWritable one = new IntWritable(1);
        private Text word = new Text();

        public void map(Object key, Text value, Context context)
            throws IOException, InterruptedException {

            StringTokenizer itr = new StringTokenizer(value.toString());

            while (itr.hasMoreTokens()) {
                word.set(itr.nextToken().toLowerCase());
                context.write(word, one);
            }
        }
    }

    public static class IntSumReducer
        extends Reducer<Text, IntWritable, Text, IntWritable> {

        private Text maxWord = new Text();
        private int maxCount = 0;

        public void reduce(Text key, Iterable<IntWritable> values,
            Context context) throws IOException, InterruptedException {

            int sum = 0;

            for (IntWritable val : values) {
                sum += val.get();
            }

            if (sum > maxCount) {
                maxCount = sum;
                maxWord.set(key);
            }
        }

        protected void cleanup(Context context)
            throws IOException, InterruptedException {

            context.write(maxWord, new IntWritable(maxCount));
        }
    }

    public static void main(String[] args) throws Exception {

        Configuration conf = new Configuration();

        Job job = Job.getInstance(conf, "Most Frequent Word");

        job.setJarByClass(MostFrequentWord.class);

        job.setMapperClass(TokenizerMapper.class);
        job.setCombinerClass(IntSumReducer.class);
        job.setReducerClass(IntSumReducer.class);

        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);

        // Only one reducer to find the global maximum
        job.setNumReduceTasks(1);

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));

        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
EOF

echo "Creating input file..."
cat > input.txt << "EOF"
hello world hello hadoop
hadoop is powerful
mapreduce is scalable
hello mapreduce world
big data processing with hadoop
EOF

echo "Compiling..."
mkdir -p classes
javac -classpath `hadoop classpath` -d classes MostFrequentWord.java

if [ $? -ne 0 ]; then
    echo "Compilation failed"
    exit 1
fi

echo "Creating JAR..."
jar -cvf mostfrequent.jar -C classes/ .

echo "Cleaning HDFS..."
hdfs dfs -rm -r -f /input
hdfs dfs -rm -r -f /output

echo "Uploading input to HDFS..."
hdfs dfs -mkdir -p /input
hdfs dfs -put input.txt /input

echo "Running MapReduce job..."
hadoop jar mostfrequent.jar MostFrequentWord /input /output

if [ $? -ne 0 ]; then
    echo "Job failed"
    exit 1
fi

echo "Final Output:"
hdfs dfs -cat /output/part-r-00000
