#!/bin/bash
# programas utilizados: mencoder ffprobe bc mkvtoolnix jq

setresolucao()
{
	coded_width=$(ffprobe -v quiet -show_format -show_streams "$arq" | grep coded_width=)
	coded_height=$(ffprobe -v quiet -show_format -show_streams "$arq" | grep coded_height=)
	coded_width=${coded_width#coded_width=}
	coded_height=${coded_height#coded_height=}
	if [[ -z $coded_width ]] || [[ -z $coded_height ]]; then
		echo "Erro na definição da resolução: Leitura de variáveis incorreta"
		sleep 5
		skip_file=1
	else
		altura=$(echo "670/($coded_width/$coded_height)" | bc -l)	#Calcula precisamente o valor da altura por regra de 3
		altura=$(echo "($altura+0.5)/1" | bc )						#Arredonda o valor da altura para um inteiro
		echo "A resolução será 670x$altura"
		skip_file=0
	fi
}

converter()
{
	echo "A conversão começará em 10 segundos"
	sleep 10
	mkdir convertidos
	exec_numb=0
	while [ $exec_numb -lt $n_ext ]
	do
		exec_numb=$(( exec_numb+1 ))		    #incrementa a variável para registrar que o while foi executado mais uma vez
		eval extensao='$'extensao_$exec_numb    #A variável "extensao" vai receber o valor contido na variável "extensao_X", da função "setextensao"
		for arq in *.$extensao
		do
			echo -e "\e[1;35mConvertendo $arq\e[0m"
			setresolucao						#chama a função que configura a resolução individualmente para cada arquivo
			#srtextract							#chama a função que irá extrair a legenda do arquivo de vídeo para um arquivo srt
			if [ $skip_file -eq 0 ]; then
				sleep 2
				mencoder "$arq" -oac mp3lame -lameopts br=256 -af resample=48000 -ovc lavc -vf scale=670:$altura -ffourcc XVID -alang $a_lang -lavcopts vbitrate=16000:autoaspect -nosub -msgcolor -o convertidos/"${arq/.$extensao/.avi}"
				echo	#pula uma linha após o fim da saída de texto do mencoder
			else
				echo "Pulando conversão do arquivo devido a erro na definição de variáveis"
				sleep 5
			fi
		done
	done
	echo "Fim do processo de conversão"
}

copia()
{
	echo "Iniciando cópia dos arquivos"
	sleep 5
	while read origem destino
	do
		conv_count=$(ls -1 convertidos/"$origem"* 2>/dev/null | wc -l)  
		if [ $conv_count != 0 ]; then
			mv -v convertidos/"$origem"* ~/"$destino" #entao, o asterisco tem que vir depois pq se ele estiver dentro das aspas o sistema reconhece que faz parte da palavra, e nao como caractere "de abrangencia"
		fi
	done < "$db_file"
	if [ "$(ls -A convertidos)" ]; then
		mv -v convertidos/*    ~/Public/Videos/    #Embora não tenha deixar essa linha da DB, essa e uma maneira de garantir que sera a última a ser executada
	fi
	echo "Fim da cópia dos arquivos"
}

montar()
{
	if mountpoint -q ~/Public/Videos/; then
		echo "Pasta Videos já montada, pulando montagem"
		montada=1
	else
		echo "Montando a pasta Videos de Nabucodonosor"
		montada=0
		mount ~/Public/Videos/
		if mountpoint -q ~/Public/Videos/; then
			echo "Montagem bem sucedida"
		else
			echo "Erro na montagem, a pasta não foi montada"
			echo "Interrompendo script"
			exit 1
		fi
	fi
}

desmontar()
{
	if [ $montada -eq 0 ]; then
		echo "Desmontando a pasta Vídeos"
		umount ~/Public/Videos/
		if mountpoint -q ~/Public/Videos/; then
			echo "Houve um erro na desmontagem"
			echo "A Pasta não foi desmontada"
		else
			echo "Desmontagem bem sucedida"
		fi
	else
		echo "A pasta vídeos não será desmontada pois já estava montada antes da execução do script"
	fi
}

delete()
{
	if [ $autodelete -eq 1 ]; then
		echo "Deletando pasta '$datual'"
		cd ~
		rm -vrf "$datual"
	else
		echo "Deletar a pasta '$datual'?"
		echo "S/n"
		read deletar
		case $deletar in
			S|""|s)
				echo "Deletando pasta '$datual'"
				cd ~
				rm -vrf "$datual" ;;
			n|N)
				echo "A pasta '$datual' não foi deletada" ;;
			*)
				echo "Responda 'S' para Sim, 'n' para Não ou deixe em branco para 'Sim'"
				delete ;;
		esac
	fi
}

checkempty()
{
	if [ ! "$(ls -A convertidos)" ]; then
		echo "A pasta 'convertidos' está vazia, isso provavelmente ocorreu por um erro na conversão"
		echo "Encerrando o script"
		sleep 10
		exit 1
	fi
}

setextensao()
{
	echo "Selecione o número de extensões diferentes dos arquivos de origem"
	echo "Deixe em branco para 1"
	read n_ext		#numero de extensões - essa variável controla quantas vezes o while deve ser executado
	if [ ! "$n_ext" ]; then
		n_ext=1
	fi
	exec_numb=0		#numero de vezes executado - essa variável controla quantas vezes o while foi executado
	while [ $exec_numb -lt $n_ext ]
	do
		exec_numb=$(( exec_numb+1 ))		#incrementa a variável para registrar que o while foi executado mais uma vez
		echo "Selecione a extensão $exec_numb"
		if [ "$exec_numb" = 1 ]; then
			echo "Deixe em branco para 'mkv'"
		fi
		read leitura_extensao
		if [ "$exec_numb" = 1 ]; then
			if [ ! "$leitura_extensao" ]; then
				leitura_extensao=mkv
			fi
		fi
		if [ ! "$leitura_extensao" ]; then
			echo "Você deve digitar uma extensão"
			echo
			setextensao
		fi
		eval extensao_$exec_numb='$'leitura_extensao    #com esse comando, a variável "extensao_X", sendo X um número, armazena o valor digitado acima
	done
}

setlang()
{
	echo "Por favor, selecione o idioma preferencial que deve ser utilizado na conversão"
	echo "Deixe em branco para 'por'"
	read a_lang
	case $a_lang in
		*[0-9]*)
			echo "Números não são permitidos"
			setlang ;;
	esac    
	if [ ! "$a_lang" ]; then
		a_lang=por
	fi
	echo "O idioma preferencial que será usado na conversão será o '$a_lang'"
}

checkargumento()
{
	i=0
	for argumento in $*
	do
		i=$(($i+1))		#dafuq é essa linha, Gabriel?
		case $argumento in
			-d)
				echo -e "\e[01;31mAVISO:\e[0m"
				echo "O argumento \"-d\" foi utilizado, autorizando a remoção automática do diretório atual no fim do script sem questionar"
				echo
				autodelete=1 ;;
			*)
				echo "Foi utilizado um argumento inválido"
				echo "Interrompendo script"
				exit 1 ;;
			#X) Um argumento que permita juntar todas as saídas em um único arquivo, como esse comando "mencoder -oac copy -ovc copy file1.avi file2.avi file3.avi -o full_movie.avi"
			#X) Um argumento de defina um diretório atual diferente
		esac 
	done
}

checkconvertidos()
{
	if [ -d "convertidos" ]; then
		echo "A pasta 'convertidos' já existe, isso pode significar que os arquivos já foram convertidos mas por algum motivo não foram copiados"
		echo "Deseja pular a conversão e simplesmente copiar os arquivos para a pasta Videos?"
		echo "S/n"
		read pular
		case $pular in
			S|""|s)
				echo "Pulando a conversão"
				onlycopy=1 ;;
			*)
				echo "A conversão NÃO será ignorada, e os arquivos já convertidos TAMBÉM SERÃO copiados para a pasta Videos" ;;
		esac
	fi
}

checkdbfile()
{
	if [ ! -e "$db_file" ]; then  #Checa a existência do arquivo de banco de dados; esse comando está depois da função 'checkargumento' caso algum argumento dela utilize outro DB
		echo "Erro na localização do banco de dados ($db_file)"
		echo "Interrompendo Script"
		exit 1
	fi
}

ambientvar()
{
	db_file=/home/gabriel/Documentos/Shell\ Scripts/Mencoder/SMS_autocopy.db #Minha conclusão, que pode estar errada, é que ao declarar um file path não utiliza-se aspas, mas na hora que utilizá-lo, sim
	datual=$(pwd)
	onlycopy=0
	autodelete=0
	ffprobe_command="ffprobe -v quiet -show_format -show_streams -print_format json"
}

srtextract()
{
	if [ ! -f "$datual/$filename.srt" ] && [ "a_lang" != "por" ]; then	#Uma função que detecta se existe uma faixa em 'por' no vídeo é melhor (para o 2º test)
		n_fluxos_pt=0
		stream_num=0
		filename=${arq%.$extensao*}
		stream_indexes=$($ffprobe_command "$datual"/"$arq" | jq .streams[].index | wc -l)

		stream_num=0
		while [ $stream_num -lt $stream_indexes ]; do
			if [ "$($ffprobe_command "$datual"/"$arq" | jq .streams[$stream_num].codec_type)" == "\"subtitle\"" ]; then
				srt_streams="${srt_streams} $stream_num"
			fi
			((stream_num++))
		done
		for fluxo in $srt_streams; do
			fluxo_lang=$($ffprobe_command "$datual"/"$arq" | jq .streams[$fluxo].tags.language)
			echo "O fluxo $fluxo tem idioma $fluxo_lang"
			if [ "$fluxo_lang" == "\"por\"" ]; then
				por_stream="${por_stream} $fluxo"
				((n_fluxos_pt++))
			fi
		done
		if [ $n_fluxos_pt -eq 1 ]; then
			echo "Foi encontrado um fluxo de legenda em portugues dentro do arquivo de vídeo"
			echo "Extraindo fluxo de legenda para arquivo srt..."
			mkvextract tracks "$datual"/"$arq" $por_stream:"$datual/$filename.srt"
		else
			if [ $n_fluxos_pt -gt 1 ]; then
				echo "ALERTA: Não há arquivo externo de legenda para '$arq' MAS foi encontrado mais de um fluxo de legenda em portugues no arquivo de video"
				echo "O script não irá fazer nada"
				sleep 5
			fi
		fi
	fi
}

copiasrt()
{
	#esta função copiará os arquivos srt para a pasta 'convertidos' (ela deve avisar ao usuário caso os arquivos tenham sido copiados)
}

main()
{
	echo "Bem vindo ao programa de conversão e cópia automática para o SMS do PS2"
	echo "Esse programa usa mencoder"
	echo
	ambientvar          #Seta variáveis que serão as mesmas em todas as funções e são necessárias desde sempre
	checkargumento $*	#A ideia dessa função é checar os argumentos dados ao script e tomar as medidas para tal. $* passa todos os argumentos do sript para a função
	echo "O diretório atual é: \"$datual\""
	checkdbfile         #Checa se o arquivo de banco de dados existe (lembrando que um argumento pode indicar outro DB, por isso ele checa depois da função 'checkargumento')
	checkconvertidos    #checa se a pasta 'convertidos' existe
	if [ $onlycopy -eq 0 ]; then	#se 'onlycopy' for igual a 1, todos os passos referentes a conversão dos arquivos serão pulados
		setextensao
		setlang			#Chama a função que configura o idioma
		converter		#Função da conversão propriamente dita
		#copiasrt 		#Função que copia os arquivos de legenda para a pasta 'convertidos'
	fi
	checkempty		#Esta função checa se a pasta convertidos está vazia
	montar          #chama a função que monta a pasta videos
	copia           #Copia os arquivos para a pasta Videos
	desmontar       #desmonta a pasta Videos
	delete			#chama a função delete, que (obviamente) irá deletar a pasta do script e tudo contido nela
	echo "Fim do script"
	sleep 2
	exit 0
}

#inicia a função main
main $*