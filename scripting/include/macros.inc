//Python + C-style coperators
#define and			&&
#define and_eq			&=
#define bitand			&
#define bitor			|
#define compl			~
#define not			!
#define not_eq			!=
#define or			||
#define or_eq			|=
#define xor			^
#define xor_eq			^=
#define bitl			<<
#define bitr			>>
#define eq			==
#define mod			%

//functional-style typecasting
#define int(%1)			view_as<int>(%1)
#define bool(%1)		view_as<bool>(%1)
#define Handle(%1)		view_as<Handle>(%1)
#define view-%1(%2)		view_as<%1>(%2)

//misc.
#define del			delete
#define nullfunc		INVALID_FUNCTION
#define nullvec			NULL_VECTOR
#define nullstr			NULL_STRING
#define toggle(%1)		%1 = not %1
#define tern(%1:%2)		? %1 : %2
#define max(%1, %2)		(%1 > %2) tern(%1:%2)
#define min(%1, %2)		(%1 < %2) tern(%1:%2)

#define buffer(%1)		%1, sizeof(%1)
#define strbuffer(%1)		%1, sizeof(%1)
#define PLYR			MAXPLAYERS+1
#define CLNT			MAXPLAYERS+1
#define PATH			64
#define FULLPATH		PLATFORM_MAX_PATH

#define x(%1)			%1[0]
#define y(%1)			%1[1]
#define z(%1)			%1[2]