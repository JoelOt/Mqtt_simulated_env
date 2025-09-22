function onData(from, to, data) {

    if (env["tcp.address"] == from) {

        log('Incoming Data : ' + data);

        var result_str = '';

        // Convierte el array de bytes a string
        for (var i = 0; i < data.length; i++) {
            result_str += String.fromCharCode(data[i]);
        }

        // Reemplaza el contenido deseado
        result_str = result_str.replace(/test:1/i, "test:5");

        log('MSG MOD : ' + result_str);

        // Vuelve a convertir string a string binario (charcode por byte)
        var result_bin = '';
        for (var i = 0; i < result_str.length; i++) {
            result_bin += String.fromCharCode(result_str.charCodeAt(i));
        }

        return result_bin;
    }
}
