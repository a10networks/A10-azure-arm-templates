package customplugin

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/influxdata/telegraf"
	"github.com/influxdata/telegraf/plugins/inputs"
)

type Vthtest struct {
	file_path       string
	python_exe_path string
}
type Data struct {
	Python_Exe_Path  string
	Python_File_Path string
}

func (s *Vthtest) SampleConfig() string {
	fmt.Print("Working Go!")
	return "hello telegraf custom plugin"
}

func (s *Vthtest) Gather(acc telegraf.Accumulator) error {

        /*
                Function for Gather average vthunder data usage using python script, and convert it into integer value.
        */
        content, cerr := ioutil.ReadFile("/usr/local/go/src/telegraf/plugins/inputs/customplugin/path.json")
        if cerr != nil {
                log.Fatal("Error when opening file: ", cerr)
        }
        var payload Data
        var cpuUsage float64
        jsonerr := json.Unmarshal(content, &payload)
        if jsonerr != nil {
                log.Fatal("Error during Unmarshal(): ", jsonerr)}
        err := os.Chmod(payload.Python_File_Path, 0777)
        out, err := exec.Command(payload.Python_Exe_Path, payload.Python_File_Path).Output()
        if err != nil {
                fmt.Printf("error %s", err)
        }
        numRating := string(out)
        if strings.Contains(numRating, "value") {
                numArray := strings.Split(numRating, ":-")
                val, err :=strconv.ParseFloat(strings.TrimSpace(numArray[1]), 64)
                if err!=nil{
                        fmt.Println("Error when converting to float %s",err)
                }
                fmt.Println("average cpu usage %f", val)
                cpuUsage=val
        } else {
                fmt.Println("Not found")
        }

	field := make(map[string]interface{})
	field["value"] = cpuUsage
	tag := make(map[string]string)
	acc.AddFields("value", field, tag)

	return nil
}

func init() {

	content, cerr := ioutil.ReadFile("/usr/local/go/src/telegraf/plugins/inputs/customplugin/path.json")
	if cerr != nil {
		log.Fatal("Error when opening file: ", cerr)
	}
	var payload Data
	jsonerr := json.Unmarshal(content, &payload)
	if jsonerr != nil {
		log.Fatal("Error during Unmarshal(): ", jsonerr)
	}

	inputs.Add("customplugin", func() telegraf.Input {
		return &Vthtest{python_exe_path: payload.Python_Exe_Path, file_path: payload.Python_File_Path}
	})
}
