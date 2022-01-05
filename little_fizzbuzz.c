#include <stdio.h>
int main() { for (int i=1; i<=100; i++) ((i%3!=0)&&(i%5!=0))?printf("%d\n",i):printf("%s%s\n",(i%3==0)?"Fizz":"",(i%5==0)?"Buzz":""); }