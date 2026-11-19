package com.uniminuto.zimbra;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.transaction.annotation.EnableTransactionManagement;

/**
 * Aplicación principal del Back-end Transaccional para el Caso de Estudio Zimbra y LoopFuse OneView.
 * Sesión 2: Conexión inicial a la base de datos MySQL, endpoints REST básicos y transacciones ACID.
 *
 * Autores:
 * - Maria Fernanda Chacón Criales (ID 1103928)
 * - Sergio Alberto Quiroga Gomez (ID 798170)
 * - Santiago Gonzalez Gamboa (ID 1017544)
 */
@SpringBootApplication
@EnableTransactionManagement
public class ZimbraBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(ZimbraBackendApplication.class, args);
    }
}
