//OPIS: branch, second
//RETURN: 6
int main(){
	int b;
	b = 3;
	
	branch ( b ; 1 , 3 , 5 )
	  first b = b + 1;
	  second b = b + 3;
	  third b = b + 5;
	  otherwise b = b - 3;
	
	return b;
}
