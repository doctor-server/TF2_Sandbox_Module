If you want to use Cloud Storage feature, mysql is required.

Edit the code below and paste it to configs/database.cfg,

"SaveSystem"
{
	"driver" "mysql"
	"host" "webserverURL"
	"database" "databasename"
	"user" "databaseuser"
	"pass" "dbpassword"
	//"timeout" "0"
	"port" "3306"
}

Example:
"SaveSystem"
{
	"driver" "mysql"
	"host" "localhost"
	"database" "SaveSystemStorage"
	"user" "root"
	"pass" "DontC0PyThIs"
	//"timeout" "0"
	"port" "3306"
}

By BattlefieldDuck :D
