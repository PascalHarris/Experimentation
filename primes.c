#include <stdio.h>
#include <pthread.h>
#include <sys/time.h>
#include <stdlib.h>
#include <string.h>

#define N 1000000
#define THREAD_COUNT 8 // optimal - match number of threads computer can manage

int prime_count[THREAD_COUNT]={0};

void* calculate_primes(void *ptr) {
	int j, flag, i = (int)(long long int)ptr, thread_number = i;

	while (i < N) {
		flag = 0;
		for (j = 2; j <= i/2; j++) {
			if (i % j == 0) {
				flag = 1;
				break;
			}
		}
		
		if (flag == 0 && i > 1) {
			prime_count[thread_number]++;
		}
		i+=THREAD_COUNT;
	}
	return NULL;
}

int main(int argc, char *argv[]) {
	
	printf("%lu\n",sizeof(short));
	
	struct timeval stop, start;
	int i, primes_counted = 0;
	pthread_t t_array[THREAD_COUNT] = {0};
	
	gettimeofday(&start, NULL);
	
	for (i = 0; i < THREAD_COUNT; i++) {
		pthread_create(&t_array[i], NULL, calculate_primes, (void*)(uintptr_t)i);
	}
	
	for (i = 0; i < THREAD_COUNT; i++) {
		pthread_join(t_array[i], NULL);
	}
	
	for (i = 0; i < THREAD_COUNT; i++) {
		primes_counted = primes_counted + prime_count[i];
	}
	
	printf("%d primes found\n",primes_counted);
	
	gettimeofday(&stop, NULL);
	printf("took %f sec\n", (double)((stop.tv_sec - start.tv_sec) * 1000000 + stop.tv_usec - start.tv_usec) / 1000000); 
	
	return 0;
}
