
#!/bin/bash

echo "Starting Hadoop services..."
start-dfs.sh
start-yarn.sh

echo "Creating project directory..."
mkdir -p ~/kmeans/classes
cd ~/kmeans || exit

echo "Creating KMeans.java..."
mkdir -p word

cat > word/KMeans.java << "EOF"
package word;

import java.io.IOException;
import org.apache.hadoop.io.*;
import org.apache.hadoop.mapreduce.*;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.fs.Path;

public class KMeans {

    public static class Map extends Mapper<LongWritable, Text, IntWritable, IntWritable> {

        public void map(LongWritable key, Text value, Context context)
                throws IOException, InterruptedException {

            int point = Integer.parseInt(value.toString());

            int c1 = 10;
            int c2 = 50;

            int d1 = Math.abs(point - c1);
            int d2 = Math.abs(point - c2);

            if (d1 < d2)
                context.write(new IntWritable(1), new IntWritable(point));
            else
                context.write(new IntWritable(2), new IntWritable(point));
        }
    }

    public static class Reduce extends Reducer<IntWritable, IntWritable, IntWritable, IntWritable> {

        public void reduce(IntWritable key, Iterable<IntWritable> values, Context context)
                throws IOException, InterruptedException {

            int sum = 0, count = 0;

            for (IntWritable x : values) {
                sum += x.get();
                count++;
            }

            if (count > 0)
                context.write(key, new IntWritable(sum / count));
        }
    }

    public static void main(String[] args) throws Exception {

        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "KMeans Clustering");

        job.setJarByClass(KMeans.class);
        job.setMapperClass(Map.class);
        job.setReducerClass(Reduce.class);

        job.setOutputKeyClass(IntWritable.class);
        job.setOutputValueClass(IntWritable.class);

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));

        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
EOF

echo "Creating input file..."
cat > input.txt << "EOF"
10
12
15
48
50
55
EOF

echo "Compiling..."
javac -classpath `hadoop classpath` -d classes word/KMeans.java

if [ $? -ne 0 ]; then
    echo "Compilation failed"
    exit 1
fi

echo "Creating JAR..."
jar -cvf kmeans.jar -C classes/ .

echo "Cleaning HDFS..."
hdfs dfs -rm -r -f /input
hdfs dfs -rm -r -f /output

echo "Uploading input to HDFS..."
hdfs dfs -mkdir -p /input
hdfs dfs -put input.txt /input

echo "Running K-Means MapReduce..."
hadoop jar kmeans.jar word.KMeans /input /output

if [ $? -ne 0 ]; then
    echo "Job failed"
    exit 1
fi

echo "Final Output:"
hdfs dfs -cat /output/part-r-00000

echo "K-Means execution completed!"
